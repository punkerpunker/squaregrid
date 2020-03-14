import argparse
from collections import defaultdict
from concurrent import futures
from flask import Flask, request, render_template
from hashlib import sha256
import io
import itertools
import json
import logging
import os
import pandas
import requests
import signal
import sqlalchemy
import time
from threading import Thread, Lock

import grpc

from processing.geocoder_pb2 import GeocodeCSVRequest, GeocodeCSVResponse
from processing.geocoder_pb2 import StoredRequest, PullProcessedDataResponse
from processing.geocoder_pb2 import PullProcessedDataRequest
from processing import geocoder_pb2_grpc
from processing.geocoder_pb2_grpc import GeocoderServicer, GeocoderStub
from utils.flask import FlaskServingThread

class Geocoder(GeocoderServicer):
	# RPC API
	def GeocodeCSV(self, geo_request, context):
		logging.debug('GeocodeCSV request recived')
		if (not geo_request.HasField('data')
				or geo_request.data.tag == ''
				or geo_request.data.address_column == ''):
			return GeocodeCSVResponse(
					error=2, comment='Some fields are not specified')

		request = StoredRequest()
		request.data.CopyFrom(geo_request.data)
		request.status = StoredRequest.RECIEVED
		error, unique_id = self.add_request_(request, dump_to_file=True)
		if error != 0:
			return GeocodeCSVResponse(
					error=error, comment='failed to proccess request')
		return GeocodeCSVResponse(error=0, unique_id=unique_id)

	def PullProcessedData(self, request, context):
		with self.requests_lock_:
			response = PullProcessedDataResponse()
			to_cleanup = list()
			for entry in os.scandir(self.dump_dir_):
				if not entry.is_file():
					continue
				req_str = open(entry.path, 'rb').read()
				req = StoredRequest()
				req.ParseFromString(req_str)
				if req.status == StoredRequest.COMPLETED:
					if (request.filter_by_tag != ''
							and request.filter_by_tag != req.data.tag):
						continue

					response.data.extend([req.data])
					if request.delete_pulled_data:
						to_cleanup.append(entry.path)
			logging.debug('Pulled {} processed requests; cleaned up {}'.format(
				len(response.data), len(to_cleanup)))
			for path in to_cleanup:
				os.unlink(path)
			return response
	# end of RPC API

	def __init__(self, *, dump_dir, salt, update_freq, backend_uri, table_name,
			bulk_insert_limit):
		self.salt_ = salt
		self.dump_dir_ = dump_dir
		self.update_freq_ = update_freq
		self.backend_uri_ = backend_uri
		self.bulk_insert_limit_ = bulk_insert_limit

		self.requests_ = dict()
		self.requests_lock_ = Lock()

		self.active_group_tags_ = defaultdict(list)

		logging.debug('Initialising database connection')
		self.engine_ = sqlalchemy.create_engine(self.backend_uri_, echo=False)
		self.engine_lock_ = Lock()

		with self.engine_lock_:
			metadata = sqlalchemy.MetaData(bind=self.engine_)
			self.geo_table_ = sqlalchemy.Table('geo', metadata, autoload=True)

		logging.debug('Checking for dropped requests')
		self.shutting_down_ = False
		self.check_dropped_requests()

		logging.debug('Starting monitoring thread')
		self.monitor_thread_ = Thread(
			target=self.monitor_, name='BackendMonitoringThread')
		self.monitor_thread_.start()

	def check_dropped_requests(self) -> None:
		for entry in os.scandir(self.dump_dir_):
			if not entry.is_file():
				continue
			request_str = open(entry.path, 'rb').read()
			request = StoredRequest()
			request.ParseFromString(request_str)
			if request.status == StoredRequest.COMPLETED:
				continue

			req_id = self.get_request_id_(request)
			if req_id != entry.name:
				raise RuntimeError(('Cannot match {} and its hash {},'
					' check if salt is correct').format(entry.path, req_id))

			error, _ = self.add_request_(request, dump_to_file=False)
			logging.debug('Dropped request {}, location: {}'.format(
				'picked up' if error == 0 else 'skipped',
				entry.path))


	def run_http_server(self, port):
		if getattr(self, 'app_', None) is None:
			app = Flask(__name__, template_folder='templates')

			@app.route('/', methods=['GET'])
			def index():
				return render_template(
						'geocoder_index.html',
						requests=self.requests_.items())

			self.app_ = app
			self.flask_thread_ = FlaskServingThread(self.app_, '0.0.0.0', port)
			self.flask_thread_.start()

	def shutdown(self, timeout=None) -> None:
		logging.info('Caught shutdown signal, waiting for threads')
		if timeout is None:
			timeout = self.update_freq_ * 2
		self.shutting_down_ = True
		self.monitor_thread_.join(timeout=timeout)
		if self.monitor_thread_.isAlive():
			raise RuntimeError(
				'Server has not shut down with timeout=%s' % str(timeout))

		self.flask_thread_.shutdown()
		logging.info('Shutdown reached')

	def get_request_id_(self, request) -> str:
		hash_obj = sha256()
		hash_obj.update(self.salt_.encode('utf-8'))
		hash_obj.update(request.data.SerializeToString())
		return hash_obj.hexdigest()

	def dump_request_(self, request, req_id=None) -> None:
		if req_id is None:
			req_id = self.get_request_id_(request)
		file_path = os.path.join(self.dump_dir_, req_id)
		with open(file_path, 'wb') as out_file:
			out_file.write(request.SerializeToString())
		logging.debug('Request dumped into {}'.format(file_path))

	def add_request_(self, request, dump_to_file=True) -> (int, int):
		unique_id = -1
		if request.status == StoredRequest.COMPLETED:
			return (1, unique_id)

		req_id = self.get_request_id_(request)
		logging.debug('Adding request {}'.format(req_id))

		with self.requests_lock_:
			if req_id in self.requests_:
				return (1, unique_id)
			self.requests_[req_id] = request

		if request.status == StoredRequest.RECIEVED:
			error, unique_id = self.request_geocoding_(request)
			if error != 0:
				return (2, unique_id)
			request.status = StoredRequest.REQUESTED
		elif request.status == StoredRequest.REQUESTED:
			self.active_group_tags_[request.group_tag].append(req_id)
		if dump_to_file:
			self.dump_request_(request, req_id=req_id)
		return (0, unique_id)

	def request_geocoding_(self, request) -> (int, int):
		try:
			req_id = self.get_request_id_(request)
			group_tag = int(req_id, 16) % 1000000007
			# we take request id modulo large prime to fit int(11)
			# collisions are quite possible (thanks to birthday paradox!)
			# one should not rely on uniqueness of group identificator

			csv_dataframe = pandas.read_csv(io.StringIO(
				request.data.csv.decode('utf-8')))
			uniques = csv_dataframe[request.data.address_column].dropna().unique()
			with self.engine_lock_:
				logging.debug('Pushing data to geocoder')
				inserted = 0
				for i in range(0, len(uniques), self.bulk_insert_limit_):
					insert_query = sqlalchemy.sql.insert(self.geo_table_)
					insert_query = insert_query.values([
						{'address': address, 'unique_id': group_tag}
						for address in uniques[i:i+self.bulk_insert_limit_]])
					result = self.engine_.execute(insert_query)
					inserted += result.rowcount
					logging.debug('Inserted {} of {} rows'.format(inserted, len(uniques)))
				request.group_tag = group_tag
				self.active_group_tags_[group_tag].append(req_id)

				if inserted != len(uniques):
					raise RuntimeError('Falied to insert {} rows, only {} inserted'.format(
						len(uniques), inserted))

				logging.debug('Request complete, group tag = {}, {} rows inserted'.format(
					group_tag, inserted))
				return (0, group_tag)
		except:
			return (1, -1)

	def finalize_geocoding_(self, geocoded_data) -> None:
		logging.debug('Finalizing geocoding for {} addresses'.format(
			len(geocoded_data)))
		with self.requests_lock_:
			for group_tag, group in itertools.groupby(
					geocoded_data, key=lambda x: x[0]):

				address_mapping = pandas.DataFrame(
						list(map(lambda x: (x[1], x[2]), group)),
						columns=['geo_tmp_address', 'geo_tmp_json'])
				address_mapping.drop_duplicates(['geo_tmp_address'])

				logging.debug('Group tag {} is finished: {} addresses'.format(
					group_tag, len(address_mapping)))

				for req_id in self.active_group_tags_[group_tag]:
					logging.debug('Finalizing request {}'.format(req_id))
					request = self.requests_[req_id]
					csv_dataframe = pandas.read_csv(io.StringIO(
						request.data.csv.decode('utf-8')))
					result = pandas.merge(
						csv_dataframe, address_mapping, how='left',
						left_on=request.data.address_column, right_on='geo_tmp_address')

					csv_buffer = io.StringIO()
					result.to_csv(csv_buffer, index=False)
					request.data.csv = csv_buffer.getvalue().encode('utf-8')

					os.unlink(os.path.join(self.dump_dir_, req_id))
					request.status = StoredRequest.COMPLETED
					if len(request.data.output_table) > 0:
						try:
							engine = sqlalchemy.create_engine(
									'postgres://marketinglogic:tttBBB777@0.0.0.0:5432/mldata')
							schema, table = request.data.output_table.split('.')
							result.to_sql(table, schema=schema, con=engine, index=False)
							logging.debug('Request {} dumped into {}'.format(req_id,
								request.data.output_table))
						except:
							logging.debug('Failed to dump request {} into {}'.format(req_id,
								request.data.output_table))

					new_req_id = self.get_request_id_(request)
					logging.debug('Request {} completed and assigned id {}'.format(
						req_id, new_req_id))
					self.dump_request_(request, req_id=new_req_id)
					del(self.requests_[req_id])

				del(self.active_group_tags_[group_tag])

	def monitor_(self) -> None:
		while not self.shutting_down_:
			with self.engine_lock_:
				try:
					select_query = sqlalchemy.sql.select(
						[
							self.geo_table_.c.unique_id,
							sqlalchemy.sql.func.sum(self.geo_table_.c.done).label('done'),
							sqlalchemy.sql.func.count().label('count'),
						]).group_by(self.geo_table_.c.unique_id)
					select_query = select_query.where(
						self.geo_table_.c.unique_id.in_(self.active_group_tags_.keys()))
					result = self.engine_.execute(select_query)

					logging.debug('Pulled data from backend, {} groups'.format(
						result.rowcount))

					done_tags = list()
					for unique_id, done, count in result:
						if done != count:
							continue
						done_tags.append(unique_id)

					logging.debug('{} tags are completed'.format(len(done_tags)))
					if len(done_tags) > 0:
						select_query = sqlalchemy.sql.select([
								self.geo_table_.c.unique_id,
								self.geo_table_.c.address,
								self.geo_table_.c.json
							])
						select_query = select_query.where(
							self.geo_table_.c.unique_id.in_(done_tags))
						geocoded_data = list(self.engine_.execute(select_query))

						# cleanup_query = self.geo_table_.delete(
						#     self.geo_table_.c.unique_id.in_(done_tags))
						# result = self.engine_.execute(cleanup_query)
						# logging.debug('Cleaned up {} rows'.format(result.rowcount))

						self.finalize_geocoding_(geocoded_data)
				except:
						logging.exception('Uncaught exception during monitoring requests')
			time.sleep(self.update_freq_)


def parse_geo_json(df, prefix='', whitelist=None) -> pandas.DataFrame:
	extract_columns = [
			(
				'country_code',
				[['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
					'CountryNameCode']],
			),
			(
				'country',
				[['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
					'CountryName']],
			),
			(
				'county',
				[
					['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
						'AdministrativeArea', 'SubAdministrativeArea',
						'SubAdministrativeAreaName'],
					['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
						'AdministrativeArea', 'SubAdministrativeAreaName']
				],
			),
			(
				'state',
				[['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
					'AdministrativeArea', 'AdministrativeAreaName']],
			),
			(
				'city',
				[
					['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
						'AdministrativeArea', 'SubAdministrativeArea', 'Locality',
						'LocalityName'],
					['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
						'AdministrativeArea', 'Locality', 'LocalityName']
				],
			),
			(
				'street',
				[
					['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
						'AdministrativeArea', 'SubAdministrativeArea', 'Locality',
						'Thoroughfare', 'ThoroughfareName'],
					['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
						'AdministrativeArea', 'Locality', 'Thoroughfare',
						'ThoroughfareName']
				],
			),
			(
				'housenumber',
				[
					['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
						'AdministrativeArea', 'SubAdministrativeArea', 'Locality',
						'Thoroughfare', 'Premise', 'PremiseNumber'],
					['metaDataProperty', 'GeocoderMetaData', 'AddressDetails', 'Country',
						'AdministrativeArea', 'Locality', 'Thoroughfare', 'Premise',
						'PremiseNumber']
				],
			),
			('address', [['metaDataProperty', 'GeocoderMetaData', 'text']]),
			('latlong', [['Point', 'pos']]),
			('bbox', [['boundedBy', 'Envelope']]),
			('accuracy', [['metaDataProperty', 'GeocoderMetaData', 'kind']]),
			('quality', [['metaDataProperty', 'GeocoderMetaData', 'precision']]),
	]
	for col_name, _ in extract_columns:
		if whitelist is not None and col_name not in whitelist:
			continue
		if col_name == 'latlong':
			df[prefix + 'lat'] = [None] * len(df)
			df[prefix + 'lng'] = [None] * len(df)
		else:
			df[prefix + col_name] = [''] * len(df)
	for i in range(len(df)):
		try:
			parsed_json = json.loads(df.iloc[i]['geo_tmp_json'])
		except:
			logging.exception('Bad line {}'.format(i))
			continue
		for col_name, pathes in extract_columns:
			if whitelist is not None and col_name not in whitelist:
				continue
			success = False
			for path in pathes:
				try:
					cur = parsed_json['response']['GeoObjectCollection'][
							'featureMember'][0]['GeoObject']
					for entry in path:
						cur = cur[entry]
					if col_name == 'bbox':
						cur = str(cur)
					success = True
					break
				except:
					continue
			if not success:
				cur = ''
			if col_name == 'latlong':
				if len(cur) != 0:
					df.set_value(i, prefix + 'lng', float(cur.split(' ')[0]))
					df.set_value(i, prefix + 'lat', float(cur.split(' ')[1]))
			else:
				df.set_value(i, prefix + col_name, cur)
	df.drop(['geo_tmp_json', 'geo_tmp_address'], axis=1, inplace=True)
	return df

def geocode(
		df, address_column, url,
		options=[], prefix='', whitelist=None,
		output_table=None) -> pandas.DataFrame:
	channel = grpc.insecure_channel(url, options)
	stub = GeocoderStub(channel)

	csv_buffer = io.StringIO()
	df.to_csv(csv_buffer, index=False)

	request = GeocodeCSVRequest()
	request.data.csv = csv_buffer.getvalue().encode('utf-8')
	request.data.address_column = address_column
	request.data.tag = (
			'data_mart_request_' +
			sha256(request.data.csv + address_column.encode('utf-8')).hexdigest())
	if output_table is not None:
		request.data.output_table = output_table

	response = stub.GeocodeCSV(request)
	if response.error != 0:
		if response.error != 1:
			logging.error(response.comment)
			raise RuntimeError('Failed to execute request to geocoder')
		else:
			logging.debug('Request is already being processed')
	logging.debug('Sent request for geocoding, waiting...')
	unique_id = response.unique_id

	while True:
		pull_request = PullProcessedDataRequest()
		pull_request.delete_pulled_data = False
		pull_request.filter_by_tag = request.data.tag
		response = stub.PullProcessedData(pull_request)
		if len(response.data) != 0:
			assert(len(response.data) == 1)
			result = response.data[0].csv.decode('utf-8')
			df = pandas.read_csv(io.StringIO(result))
			return parse_geo_json(df, prefix=prefix, whitelist=whitelist)
		time.sleep(10)
		logging.debug('No response yet for unique_id = %d, waiting a bit more...'
				% unique_id)

def main():
	logging.basicConfig(
			filename='geocoder.log', level=logging.DEBUG,
			format='%(asctime)s %(thread)s %(threadName)s %(levelname)s: %(message)s')
	console = logging.StreamHandler()
	console.setLevel(logging.DEBUG)
	console.setFormatter(logging.Formatter(
		'%(asctime)s %(thread)s %(threadName)s %(levelname)s: %(message)s'))
	logging.getLogger('').addHandler(console)

	parser = argparse.ArgumentParser(
			description='Run the geocoding service',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('--salt', type=str, default='geocoder_salt',
			help='Salt used for hashing')
	parser.add_argument('--dump_dir', type=str, default='./req_dump',
			help='Directory for storing requests')
	parser.add_argument('--update_freq', type=int, default=10,
			help='Time between consequtive data pulls in seconds')
	parser.add_argument('--serving_threads', type=int, default=5,
			help='Number of serving threads')
	parser.add_argument('--grpc_port', type=int, default=55555,
			help='Port to serve on')
	parser.add_argument('--http_port', type=int, default=44445,
			help='Port to serve on')
	parser.add_argument('--table_name', type=str, default='geo',
			help='Table name to work with')
	parser.add_argument('--backend_uri', type=str, required=True,
			help='URI of geocoding backend')
	parser.add_argument('--max_request_size', type=int, default=2000,
			help='Max request size in MBs')
	parser.add_argument('--bulk_insert_limit', type=int, default=100000,
			help='Maximum geocoder DB bulk insert size')
	args = parser.parse_args()

	request_size_in_bytes = args.max_request_size * 1024 * 1024
	server = grpc.server(
			futures.ThreadPoolExecutor(max_workers=args.serving_threads),
			options=[
				('grpc.max_send_message_length', request_size_in_bytes),
				('grpc.max_receive_message_length', request_size_in_bytes),
				('grpc.max_message_length', request_size_in_bytes)])

	geocoder = Geocoder(
		dump_dir=args.dump_dir,
		salt=args.salt,
		update_freq=args.update_freq,
		backend_uri=args.backend_uri,
		table_name=args.table_name,
		bulk_insert_limit=args.bulk_insert_limit)

	geocoder_pb2_grpc.add_GeocoderServicer_to_server(geocoder, server)
	server.add_insecure_port('[::]:%d' % args.grpc_port)
	server.start()

	geocoder.run_http_server(args.http_port)

	try:
		while True:
			time.sleep(1)
	except KeyboardInterrupt:
		geocoder.shutdown()
		server.stop(0)

if __name__ == '__main__':
	main()
