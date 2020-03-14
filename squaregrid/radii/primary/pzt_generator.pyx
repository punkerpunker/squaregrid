from primary.pzt_generator_pb2 import MakePZTMartResponse, MakePZTMartRequest
from primary import pzt_generator_pb2_grpc
from primary.pzt_generator_pb2_grpc import PZTGeneratorServicer
from primary.pzt_generator_pb2_grpc import PZTGeneratorStub
from primary.pzt_legacy_code import make_pzt
from processing.geocoder import geocode
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

class PZTGenerator(PZTGeneratorServicer):
	# gRPC API
	def MakePZTMart(self, request, context):
		logging.debug('MakePZTMartRequest recieved')
		df = create_df_from_datamart(request.source_mart)
		logging.debug('Starting geocoding')
		request_size_in_bytes = self.max_request_size_ * 1024 * 1024
		df = geocode(
				df, request.address_column, self.geocoder_url_,
				prefix='', options=[
					('grpc.max_send_message_length', request_size_in_bytes),
					('grpc.max_receive_message_length', request_size_in_bytes),
					('grpc.max_message_length', request_size_in_bytes)])
		df.rename(columns={'lat': 'gc_lat', 'lng': 'gc_lng'}, inplace=True)
		logging.debug('Calculating the response')
		# To be continued
		result_df = make_pzt(df, request, self.sql_engine_, self.cores_per_request_)
		response = MakePZTMartResponse()
		response.status = 0
		if len(request.output_table) > 0:
			try:
				schema, table = request.output_table.split('.')
				result_df.to_sql(
						table, self.sql_engine_, schema=schema,
						index=False, if_exists='append')
				logging.debug('Pushed dataframe to DB')
			except:
				response.status = 2
				response.comment = (
						'Failed to insert data into DB. '
						'Table already exists (and does not match?)')
		if request.return_mart:
			response.data_mart.CopyFrom(create_datamart_from_df(result_df))
		return response
	# end of gRPC API

	def __init__(
			self, sql_engine, geocoder_url, max_request_size, cores_per_request):
		self.sql_engine_ = sql_engine
		self.max_request_size_ = max_request_size
		self.geocoder_url_ = geocoder_url
		self.cores_per_request_ = cores_per_request

	def run_http_server(self, port, backend_url, geocoder_url, max_request_size):
		if getattr(self, 'app_', None) is None:
			app = Flask(__name__, template_folder='templates')
			app.secret_key = '1b3a995ec40fa1a63653c129e5e6a672'


			@app.route('/', methods=['GET', 'POST'])
			def index():
				if request.method == 'GET':
					return render_template('pzt_generator_index.html')
				else:
					fail = False
					if 'file' not in request.files:
						fail = True
						flash('No file specified')
					try:
						df = pandas.read_csv(
								request.files['file'].stream, sep=request.form['sep'])
					except Exception as e:
						fail = True
						flash('Cannot parse csv: ' + str(e))

					try:
						if int(request.form['rank']) < 0:
							fail = True
							flash('rank must be nonnegative')
					except:
						fail = True
						flash('rank must be a NUMBER ._.')

					try:
						if float(request.form['distance']) < 0:
							fail = True
							flash('distance must be nonnegative')
					except:
						fail = True
						flash('distance must be a NUMBER ._.')

					try:
						if int(request.form['chunksize']) < 0:
							fail = True
							flash('chunk size must be nonnegative')
					except:
						fail = True
						flash('chunk size must be a NUMBER ._.')

					FakeArgs = collections.namedtuple(
							'FakeArgs', ['rank', 'distance', 'chunksize',
								'output_file', 'output_table', 'address_column',
								'max_request_size', 'backend_url'])

					args = FakeArgs(
							rank=int(request.form.get('rank')),
							address_column=request.form.get('address_column'),
							distance=float(request.form['distance']),
							chunksize=int(request.form['chunksize']),
							output_file=None,
							output_table=request.form['output_table'],
							max_request_size=max_request_size,
							backend_url=backend_url)
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

def execute_request(df, args):
	for arg in ['rank', 'distance', 'chunksize']:
		if getattr(args, arg, None) is None:
			raise ValueError('--%s not specified' % arg)
	request_size_in_bytes = args.max_request_size * 1024 * 1024
	channel = grpc.insecure_channel(
			args.backend_url, options=[
				('grpc.max_send_message_length', request_size_in_bytes),
				('grpc.max_receive_message_length', request_size_in_bytes),
				('grpc.max_message_length', request_size_in_bytes)])
	stub = PZTGeneratorStub(channel)

	request = MakePZTMartRequest()
	request.rank = args.rank
	request.distance = args.distance
	request.chunk_size = args.chunksize
	if args.output_table is not None:
		request.output_table = args.output_table
	request.return_mart = args.output_file is not None
	request.address_column = args.address_column
	request.source_mart.CopyFrom(create_datamart_from_df(df))

	response = stub.MakePZTMart(request)
	if response.status != 0:
		logging.error(response.comment)
	else:
		if args.output_file is not None:
			out_df = create_df_from_datamart(response.data_mart)
			out_df.to_csv(args.output_file, index=False)
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

	generator = PZTGenerator(
			engine, args.geocoder_url, args.max_request_size,
			args.threads_per_request)
	pzt_generator_pb2_grpc.add_PZTGeneratorServicer_to_server(generator, server)
	server.add_insecure_port('[::]:%d' % args.grpc_port)
	server.start()

	generator.run_http_server(
			port=args.http_port,
			backend_url='0.0.0.0:%d' % args.grpc_port,
			geocoder_url=args.geocoder_url,
			max_request_size=args.max_request_size)

	try:
		while True:
			time.sleep(1)
	except KeyboardInterrupt:
		generator.shutdown()
		server.stop(0)


def main():
	logging.basicConfig(
			level=logging.DEBUG,
			format='%(asctime)s %(thread)s %(threadName)s %(levelname)s: %(message)s')
	parser = argparse.ArgumentParser(
			description='PZT marts service',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)

	action_group = parser.add_mutually_exclusive_group(required=True)
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

	parser.add_argument('--rank', default=16, type=int)
	parser.add_argument('--distance', default=3.0, type=float)
	parser.add_argument('--chunksize', default=300, type=int)

	parser.add_argument('--output_table', type=str, default=None,
			help='Output table')
	parser.add_argument('--output_file', type=str, default=None,
			help='Output file')

	parser.add_argument('--address_column', type=str, default=None,
			help='Name of address column')
	parser.add_argument('--geocoder_url', type=str, default='127.0.0.1:55555',
			help='Address of geocoder service')
	parser.add_argument('--backend_url', type=str, default='127.0.0.1:55558',
			help='URL of backend service')

	parser.add_argument('--max_request_size', type=int, default=2000,
			help='Max service request size in MBs')
	parser.add_argument('--serving_threads', type=int, default=5,
			help='Number of serving threads')
	parser.add_argument('--threads_per_request', default=30, type=int)
	parser.add_argument('--grpc_port', type=int, default=55558,
			help='Port to serve on')
	parser.add_argument('--http_port', type=int, default=44448,
			help='Port to serve on')

	args = parser.parse_args()

	if args.execute_request:
		if args.input_file is None:
			raise ValueError('--input_file not specified')
		df = pandas.read_csv(args.input_file)
		execute_request(df, args)

	if args.start_service:
		start_service(args)

if __name__ == '__main__':
	main()
