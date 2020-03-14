import argparse
from hashlib import sha256
import io
import json
import logging
import numpy
import os
import pandas
import time

import grpc

from primary.data_mart_manager_pb2_grpc import DataMartManagerStub
from primary.data_mart_manager_pb2 import MakeDataMartRequest
from utils.datamart_pb2 import DataMart

from processing.geocoder import geocode
from utils.datamart import create_datamart_from_df, create_df_from_datamart

options=[
	('grpc.max_send_message_length', 2000 * 1024 * 1024),
	('grpc.max_receive_message_length', 2000 * 1024 * 1024),
	('grpc.max_message_length', 2000 * 1024 * 1024)]

def make_data_mart(
		df, prefix, lat_col, lng_col, tables, url,
		output_table, output_file):

	channel = grpc.insecure_channel(url, options)
	stub = DataMartManagerStub(channel)

	request = MakeDataMartRequest()

	data = create_datamart_from_df(df)
	request.data.CopyFrom(data)
	request.longitude_column = list(df.columns).index(lng_col)
	request.latitude_column = list(df.columns).index(lat_col)
	request.prefix = prefix
	for t in tables:
		r = tables[t]
		cur = request.tables.add()
		cur.table_name = t
		cur.radii.extend(r)
	if output_table is not None:
		request.output_table = output_table
	request.return_mart = output_file is not None

	logging.debug('Sending request to DMManager')

	response = stub.MakeDataMart(request)
	if response.error != 0:
		logging.error(response.comment)
		raise RuntimeError('Failed to execute request to DMManager')

	df = create_df_from_datamart(response.data)
	if output_file is not None:
		print(df.head())
		df.to_csv(output_file, index=False)

def main():
	logging.basicConfig(
			level=logging.DEBUG,
			format='%(asctime)s %(thread)s %(threadName)s %(levelname)s: %(message)s')
	parser = argparse.ArgumentParser(
			description='Run the geocoding service',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('--input', type=str, required=True,
			help='Input CSV file')
	parser.add_argument('--sep', type=str, default=',', help='CSV separator')

	parser.add_argument('--output_file', type=str, default=None,
			help='Output CSV file')
	parser.add_argument('--output_table', type=str, default=None,
			help='Output table')

	parser.add_argument('--prefix', type=str, default='',
			help='Prefix for added columns')


	parser.add_argument('--make_mart', action='store_true', help='Make datamart?')
	parser.add_argument('--lat_col', type=str, default='lat',
			help='Name of latitude column')
	parser.add_argument('--lng_col', type=str, default='lng',
			help='Name of longitude column')
	parser.add_argument('--tables_json', type=str, default=None,
			help='JSON with description of needed radii tables')
	parser.add_argument('--tables_json_file', type=str, default=None,
			help='File with JSON with description of needed radii tables')
	parser.add_argument('--data_mart_manager_url', type=str,
			default='localhost:55556', help='Address of DMManager service')

	parser.add_argument('--geocode', action='store_true', help='Geocode data?')
	parser.add_argument('--geocoder_url', type=str, default='localhost:55555',
			help='Address of geocoder service')
	parser.add_argument('--address_column', type=str,
			help='Column with address to geocode')
	args = parser.parse_args()

	df = pandas.read_csv(args.input, sep=args.sep)

	if args.geocode:
		df = geocode(df, args.address_column, args.geocoder_url,
				prefix=args.prefix, options=options, output_table=args.output_table)
		print(df.head())
		df.to_csv(args.output_file, index=False)

	if args.make_mart:
		tables = {}
		if args.tables_json is not None:
			tables = json.loads(args.tables_json)
		elif args.tables_json_file is not None:
			with open(args.tables_json_file) as f:
				tables = json.loads(f.read())

		df = make_data_mart(
				df, args.prefix, args.lat_col, args.lng_col,
				tables, args.data_mart_manager_url,
				args.output_table, args.output_file)

if __name__ == '__main__':
	main()
