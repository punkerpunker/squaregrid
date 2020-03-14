from libcpp.vector cimport vector
from libcpp.utility cimport pair
from libcpp.string cimport string
from libcpp.algorithm cimport sort
from libcpp cimport bool as bool_t

from grids.pywrap_grid_metadata cimport GridMetadata, PywrapGridMetadata
from grids.pywrap_grid_metadata import LoadGridsMetadata
from processing.pywrap_data_grid cimport DataGrid
from processing.pywrap_grid_forming cimport FillDataGrid
from processing.pywrap_radii_summation cimport CalculateRadii
from utils.pywrap_common cimport GeoCoords
from utils.pywrap_helpers cimport OccurrenceCounter

from processing.geocoder import geocode
from primary.competitive_analysis_pb2 import MakeCompetitiveAnalysisMartRequest
from primary.competitive_analysis_pb2 import MakeCompetitiveAnalysisMartResponse
from primary.competitive_analysis_pb2_grpc import CompetitiveAnalyserServicer
from primary import competitive_analysis_pb2_grpc
from primary.competitive_analysis_pb2_grpc import CompetitiveAnalyserStub
from utils.datamart import create_df_from_datamart, create_datamart_from_df
from utils.flask import FlaskServingThread

import argparse
import collections
from concurrent import futures
from flask import Flask, request, render_template, flash, redirect
import grpc
import logging
import pandas
import time
import sqlalchemy

class CompetitiveAnalyser(CompetitiveAnalyserServicer):
	# gRPC API
	def MakeCompetitiveAnalysisMart(self, request, context):
		logging.debug('MakeCompetitiveAnalysisMartRequest recieved')
		df = create_df_from_datamart(request.source_mart)
		if len(request.address_column) > 0:
			if len(request.lat_column) > 0 or len(request.lng_column) > 0:
				return MakeCompetitiveAnalysisMartResponse(
						status=1,
						comment=('address_column AND lat/lng columns specified'))
			logging.debug('Starting geocoding')
			request_size_in_bytes = self.max_request_size_ * 1024 * 1024
			df = geocode(
					df, request.address_column, self.geocoder_url_,
					prefix=request.prefix, options=[
						('grpc.max_send_message_length', request_size_in_bytes),
						('grpc.max_receive_message_length', request_size_in_bytes),
						('grpc.max_message_length', request_size_in_bytes)],
					whitelist={'latlong'})
			request.lat_column = request.prefix + 'lat'
			request.lng_column = request.prefix + 'lng'
		else:
			if len(request.lat_column) == 0 or len(request.lng_column) == 0:
				return MakeCompetitiveAnalysisMartResponse(
						status=1,
						comment=('Too few of address_column, lat/lng columns specified'))

		logging.debug('Calculating the response')
		CalculateMart(
				df, request.lat_column, request.lng_column,
				self.sql_engine_, request.data_source.sql_query,
				list(request.radii), request.top_brands_count, request.brands_radius,
				request.prefix, request.exclude_most_common, request.tolerance)
		response = MakeCompetitiveAnalysisMartResponse()
		response.status = 0
		if len(request.output_table) > 0:
			try:
				schema, table = request.output_table.split('.')
				df.to_sql(
						table, self.sql_engine_, schema=schema,
						index=False, if_exists='append')
				logging.debug('Pushing dataframe to DB')
			except Exception as e:
				response.status = 2
				response.comment = (
						'Failed to insert data into DB. '
						'Table already exists (and does not match?)')
				logging.exception('Failed to insert data into DB')
		if request.return_mart:
			response.data_mart.CopyFrom(create_datamart_from_df(df))
		logging.debug('Response created')
		return response
	# end of gRPC API

	def __init__(self, sql_engine):
		self.sql_engine_ = sql_engine

	def run_http_server(self, port, backend_url, geocoder_url, max_request_size):
		if getattr(self, 'app_', None) is None:
			app = Flask(__name__, template_folder='templates')
			app.secret_key = '1b3a995ec40fa1a63653c129e5e6a672'

			@app.route('/', methods=['GET', 'POST'])
			def index():
				if request.method == 'GET':
					return render_template('competitive_analyser_index.html')
				else:
					fail = False
					if 'file' not in request.files:
						fail = True
						flash('No file specified')
					radii = list()
					try:
						radii = list(map(int, request.form['radii'].split(',')))
					except:
						fail = True
						flash('Cannot parse radii')
					try:
						df = pandas.read_csv(
								request.files['file'].stream, sep=request.form['sep'])
					except Exception as e:
						fail = True
						flash('Cannot parse csv: ' + str(e))

					for r in radii:
						if r % 100 != 0:
							fail = True
							flash('All items of radii list must be multiples of 100')
							break

					if len(radii) == 0:
						fail = True
						flash('Radii list is empty')

					if (request.form.get('address_column') is not None and
							len(request.form['address_column']) == 0):
						fail = True
						flash('Address column name is empty')

					if (request.form.get('lat_col') is not None and
							len(request.form['lat_col']) == 0):
						fail = True
						flash('Latitude column name is empty')

					if (request.form.get('lng_col') is not None and
							len(request.form['lng_col']) == 0):
						fail = True
						flash('Longitude column name is empty')

					try:
						if int(request.form['top_brands_count']) < 0:
							fail = True
							flash('Number of brands must be nonnegative')
					except:
						fail = True
						flash('Number of brands must be a NUMBER ._.')


					try:
						if (int(request.form['brands_radius']) < 0 or
								int(request.form['brands_radius']) % 100 != 0):
							fail = True
							flash('Brands radius must be nonnegative multiple of 100')
					except:
						fail = True
						flash('Brands radius must be a NUMBER ._.')

					if not request.form['competitors_query'].lower().startswith('select'):
						fail = True
						flash('Query must start with SELECT')

					try:
						if float(request.form['tolerance']) < 0:
							fail = True
							flash('Tolerance must be non-negative')
					except:
						fail = True
						flash('Tolerance must be real number')


					if fail:
						return redirect(request.url)

					FakeArgs = collections.namedtuple(
							'FakeArgs', ['radii', 'address_column', 'top_brands_count',
								'brands_radius', 'competitors_query', 'output_file',
								'output_table', 'max_request_size', 'backend_url', 'prefix',
								'exclude_most_common', 'tolerance', 'lat_col', 'lng_col'])

					args = FakeArgs(
							radii=radii,
							address_column=request.form.get('address_column'),
							top_brands_count=int(request.form['top_brands_count']),
							brands_radius=int(request.form['brands_radius']),
							competitors_query=request.form['competitors_query'],
							output_file=None,
							output_table=request.form['output_table'],
							max_request_size=max_request_size,
							backend_url=backend_url,
							prefix=request.form['prefix'],
							exclude_most_common=(
								request.form.get('exclude_most_common') is not None),
							tolerance=float(request.form['tolerance']),
							lat_col=request.form.get('lat_col'),
							lng_col=request.form.get('lng_col'))
					response = execute_request(df, args)
					flash('Request finished with code %d; comment = "%s"'
							% (response.status, response.comment))
					return redirect(request.url)


			self.app_ = app
			self.flask_thread_ = FlaskServingThread(self.app_, '0.0.0.0', port)
			self.flask_thread_.start()

	def shutdown(self) -> None:
		logging.info('Caught shutdown signal')
		self.flask_thread_.shutdown()
		logging.info('Shutdown reached')


def CalculateMart(
		df, lat_col, lng_col,
		sql_engine, competitors_query,
		radii, top_brands_count, brands_radius,
		prefix, exclude_most_common, tolerance):
	grids = LoadGridsMetadata(sql_engine)

	cdef vector[pair[GeoCoords, OccurrenceCounter[string]]] label_data
	cdef vector[pair[GeoCoords, int]] quan_data
	cdef GeoCoords coords
	cdef OccurrenceCounter[string] tmp_counter
	cdef int quantity
	for result_tuple in sql_engine.execute(sqlalchemy.text(competitors_query)):
		if len(result_tuple) != 3 and len(result_tuple) != 4:
			logging.error(
					'SQL query sould yield tuples (lat, lng, label [, quantity])')
			raise RuntimeError(
					'SQL query sould yield tuples (lat, lng, label [, quantity])')

		coords.lat = float(result_tuple[0])
		coords.lng = float(result_tuple[1])
		tmp_counter.data.clear()
		quantity = 1 if len(result_tuple) < 4 else result_tuple[3]
		tmp_counter.data[result_tuple[2].encode('utf-8')] = quantity

		label_data.push_back(
				pair[GeoCoords, OccurrenceCounter[string]](coords, tmp_counter))
		quan_data.push_back(pair[GeoCoords, int](coords, quantity))

	cdef int max_R = max(radii) // 100
	cdef int brands_R = brands_radius // 100
	cdef DataGrid[OccurrenceCounter[string]] grid_labels
	cdef DataGrid[int] grid_quan
	cdef vector[DataGrid[int]] radii_quan
	cdef vector[DataGrid[OccurrenceCounter[string]]] radii_labels
	cdef PywrapGridMetadata cur_grid
	cdef int i, square_x, square_y, in_grid
	cdef vector[bool_t] used = vector[bool_t](len(df), False)
	cdef vector[pair[int, string]] sorted_labels

	for r in radii:
		df[prefix + 'competitors_' + str(r)] = [0] * len(df)
	for r in range(top_brands_count):
		df[prefix + 'brands_top_' + str(r)] = [''] * len(df)
		df[prefix + 'brands_top_' + str(r) + '_count'] = [0] * len(df)
	for cur_grid in grids:
		in_grid = 0
		for idx, row in df.iterrows():
			coords.lat = row[lat_col]
			coords.lng = row[lng_col]
			if cur_grid.c_grid.GetSquareCoords(coords, &square_x, &square_y):
				in_grid += 1
				break
		if in_grid == 0:
			continue

		FillDataGrid[OccurrenceCounter[string]](
				label_data, cur_grid.c_grid[0],
				exclude_most_common, tolerance,
				&grid_labels)
		FillDataGrid[int](
				quan_data, cur_grid.c_grid[0],
				exclude_most_common, tolerance,
				&grid_quan)
		CalculateRadii[int](grid_quan, max_R + 1, &radii_quan, True)
		CalculateRadii[OccurrenceCounter[string]](
				grid_labels, brands_R + 1, &radii_labels, True)

		for idx, row in df.iterrows():
			if used[idx]:
				continue
			coords.lat = float(row[lat_col])
			coords.lng = float(row[lng_col])
			if not cur_grid.c_grid.GetSquareCoords(coords, &square_x, &square_y):
				continue
			used[idx] = True
			for j, r in enumerate(radii):
				df.set_value(
						idx, prefix + 'competitors_' + str(r),
						radii_quan[r // 100][square_x][square_y])

			sorted_labels.clear()
			for p in radii_labels[brands_R][square_x][square_y].data:
				sorted_labels.push_back(pair[int, string](p.second, p.first))
			sort(sorted_labels.begin(), sorted_labels.end())
			sorted_labels = reversed(sorted_labels)
			sorted_labels.resize(min(sorted_labels.size(), top_brands_count))
			for i in range(sorted_labels.size()):
				df.set_value(
						idx, prefix + 'brands_top_' + str(i),
						sorted_labels[i].second.decode('utf-8'))
				df.set_value(
						idx, prefix + 'brands_top_' + str(i) + '_count',
						sorted_labels[i].first)


def make_mart_inplace(args):
	for arg in ['radii', 'input_file', 'top_brands_count', 'brands_radius',
			'competitors_query', 'dbpass']:
		if getattr(args, arg, None) is None:
			raise ValueError('--%s not specified' % arg)

	args.radii = list(map(int, args.radii.split(',')))
	for r in args.radii:
		if r % 100 != 0:
			raise ValueError('All radii must be multiple of 100')

	df = pandas.read_csv(args.input_file)
	request_size_in_bytes = args.max_request_size * 1024 * 1024

	if args.address_column is not None:
		if args.lat_col is not None or args.lng_col is not None:
			raise ValueError('Address column AND lat/lng columns specified')
		df = geocode(
				df, args.address_column, args.geocoder_url,
				prefix=args.prefix, options=[
					('grpc.max_send_message_length', request_size_in_bytes),
					('grpc.max_receive_message_length', request_size_in_bytes),
					('grpc.max_message_length', request_size_in_bytes)],
				whitelist={'latlong'})
		args.lat_col = args.prefix + 'lat'
		args.lng_col = args.prefix + 'lng'
	else:
		if args.lat_col is None or args.lng_col is None:
			raise ValueError('No address column and no lat/lng column specified')

	engine = sqlalchemy.create_engine(
			'postgres://%s:%s@%s:%s/%s' % (args.dbuser, args.dbpass, args.dbhost,
				args.dbport, args.dbname))

	CalculateMart(
			df, args.lat_col, args.lng_col,
			engine, args.competitors_query,
			args.radii, args.top_brands_count, args.brands_radius,
			args.prefix, args.exclude_most_common, args.tolerance)

	if args.output_file is not None:
		df.to_csv(args.output_file, index=False)
	print(df.head())


def execute_request(df, args):
	for arg in ['radii', 'top_brands_count', 'brands_radius',
			'competitors_query']:
		if getattr(args, arg, None) is None:
			raise ValueError('--%s not specified' % arg)
	request_size_in_bytes = args.max_request_size * 1024 * 1024
	channel = grpc.insecure_channel(
			args.backend_url, options=[
				('grpc.max_send_message_length', request_size_in_bytes),
				('grpc.max_receive_message_length', request_size_in_bytes),
				('grpc.max_message_length', request_size_in_bytes)])
	stub = CompetitiveAnalyserStub(channel)

	request = MakeCompetitiveAnalysisMartRequest()
	request.data_source.sql_query = args.competitors_query
	request.radii.extend(args.radii)
	request.top_brands_count = args.top_brands_count
	if args.output_table is not None:
		request.output_table = args.output_table
	request.return_mart = args.output_file is not None
	request.prefix = args.prefix
	if args.address_column is not None:
		request.address_column = args.address_column
	if args.lat_col is not None:
		request.lat_column = args.lat_col
	if args.lng_col is not None:
		request.lng_column = args.lng_col
	request.exclude_most_common = args.exclude_most_common
	request.tolerance = args.tolerance
	request.source_mart.CopyFrom(create_datamart_from_df(df))

	response = stub.MakeCompetitiveAnalysisMart(request)
	if response.status != 0:
		logging.error(response.comment)
	else:
		if args.output_file is not None:
			out_df = create_df_from_datamart(response.data_mart)
			out_df.to_csv(args.output_file, index=False)
			print(out_df.head())
	return response


def start_service(args):
	for arg in ['dbpass']:
		if getattr(args, arg, None) is None:
			raise ValueError('--%s not specified' % arg)
	request_size_in_bytes = args.max_request_size * 1024 * 1024
	server = grpc.server(
			futures.ThreadPoolExecutor(max_workers=args.serving_threads),
			options=[
				('grpc.max_send_message_length', request_size_in_bytes),
				('grpc.max_receive_message_length', request_size_in_bytes),
				('grpc.max_message_length', request_size_in_bytes)])

	engine = sqlalchemy.create_engine(
			'postgres://%s:%s@%s:%s/%s' % (args.dbuser, args.dbpass, args.dbhost,
				args.dbport, args.dbname))

	analyser = CompetitiveAnalyser(engine)
	competitive_analysis_pb2_grpc.add_CompetitiveAnalyserServicer_to_server(
			analyser, server)
	server.add_insecure_port('[::]:%d' % args.grpc_port)
	server.start()

	analyser.run_http_server(
			port=args.http_port,
			backend_url='0.0.0.0:%d' % args.grpc_port,
			geocoder_url=args.geocoder_url,
			max_request_size=args.max_request_size)

	try:
		while True:
			time.sleep(1)
	except KeyboardInterrupt:
		analyser.shutdown()
		server.stop(0)


def main():
	logging.basicConfig(
			level=logging.DEBUG,
			format='%(asctime)s %(thread)s %(threadName)s %(levelname)s: %(message)s')
	parser = argparse.ArgumentParser(
			description='Tool for creating data marts about competitors in locality',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)

	action_group = parser.add_mutually_exclusive_group(required=True)
	action_group.add_argument(
			'--make_mart_inplace', action='store_true',
			help='Create one mart without starting service')
	action_group.add_argument(
			'--execute_request', action='store_true',
			help='Execute request to existing service?')
	action_group.add_argument(
			'--start_service', action='store_true',
			help='Start new service instance?')

	parser.add_argument('--dbuser', type=str, default='marketinglogic',
			help='DB user name')
	parser.add_argument('--dbhost', type=str, default='127.0.0.1',
			help='DB address')
	parser.add_argument('--dbport', type=str, default='5432', help='DB port')
	parser.add_argument('--dbname', type=str, default='mldata', help='DB name')
	parser.add_argument('--dbpass', type=str, default=None, help='DB password')

	parser.add_argument('--input_file', type=str, default=None,
			help='Input CSV file')
	parser.add_argument('--sep', type=str, default=',', help='CSV separator')

	parser.add_argument('--competitors_query', type=str, default=None,
			help='SQL-query yielding (lat, lng, name [, quantity])')
	parser.add_argument('--radii', type=str, default=None,
			help='Comma separated list of radii to fetch')

	parser.add_argument('--top_brands_count', type=int, default=None,
			help='Number of most common names in locality to display')
	parser.add_argument('--brands_radius', type=int, default=None,
			help='Size of locality to search for brands')
	parser.add_argument('--backend_url', type=str, default='127.0.0.1:55557',
			help='URL of backend service')

	parser.add_argument('--output_table', type=str, default=None,
			help='Output table')
	parser.add_argument('--output_file', type=str, default=None,
			help='Output file')

	parser.add_argument('--prefix', type=str, default='',
			help='String to prepend to new columns\' names')
	parser.add_argument('--address_column', type=str, default=None,
			help='Name of address column')
	parser.add_argument('--lat_col', type=str, default=None,
			help='Name of latitiude column')
	parser.add_argument('--lng_col', type=str, default=None,
			help='Name of longitude column')
	parser.add_argument('--geocoder_url', type=str, default='127.0.0.1:55555',
			help='Address of geocoder service')
	parser.add_argument('--exclude_most_common', action='store_true',
			help='Set to filter out most common coord pairs')
	parser.add_argument('--tolerance', type=float, default=1e-6,
			help='Toletance to filter out most common coord pairs')

	parser.add_argument('--max_request_size', type=int, default=2000,
			help='Max service request size in MBs')
	parser.add_argument('--serving_threads', type=int, default=5,
			help='Number of serving threads')
	parser.add_argument('--grpc_port', type=int, default=55557,
			help='Port to serve on')
	parser.add_argument('--http_port', type=int, default=44447,
			help='Port to serve on')

	args = parser.parse_args()

	if args.make_mart_inplace:
		make_mart_inplace(args)

	if args.execute_request:
		if args.input_file is None:
			raise ValueError('--input_file not specified')
		df = pandas.read_csv(args.input_file)
		execute_request(df, args)

	if args.start_service:
		start_service(args)

if __name__ == '__main__':
	main()
