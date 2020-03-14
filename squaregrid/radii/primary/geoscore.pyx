import argparse
from geopy.distance import great_circle
import grpc
import logging
import math
import numpy
import pandas
import sqlalchemy

from primary.data_mart_manager_pb2_grpc import DataMartManagerStub
from primary.data_mart_manager_pb2 import MakeDataMartRequest
from utils.datamart_pb2 import DataMart

from grids.pywrap_grid_metadata cimport GridMetadata, PywrapGridMetadata
from grids.pywrap_grid_metadata import LoadGridsMetadata
from processing.geocoder import geocode
from utils.datamart import create_datamart_from_df, create_df_from_datamart
from utils.pywrap_common cimport float_t, GeoCoords
from utils.pywrap_helpers cimport Averager

def do_geoscore(args):
	request_size_in_bytes = args.max_request_size * 1024 * 1024
	grpc_options = [
			('grpc.max_send_message_length', request_size_in_bytes),
			('grpc.max_receive_message_length', request_size_in_bytes),
			('grpc.max_message_length', request_size_in_bytes)]

	args.radii = list(map(int, args.radii.split(',')))
	for r in args.radii:
		if r % 100 != 0:
			raise ValueError('All radii must be multiple of 100')

	df = pandas.read_csv(args.input_file)
	df['ID'] = df['ID'].astype(str)

	df['dist_fact_branch'] = numpy.nan
	df['dist_fact_wrk'] = numpy.nan
	df['dist_wrk_branch'] = numpy.nan
	df['work_home_bank_angle_rad'] = numpy.nan
	for idx, row in df.iterrows():
		home_lat, home_lng = (
				row[['fact_lat', 'fact_lng']])
		work_lat, work_lng = (
				row[['wrk_lat', 'wrk_lng']])
		bank_lat, bank_lng = (
				row[['branch_lat', 'branch_lng']])
		home_bank_dst = great_circle(
				(home_lat, home_lng), (bank_lat, bank_lng)).meters
		home_work_dst = great_circle(
				(home_lat, home_lng), (work_lat, work_lng)).meters
		bank_work_dst = great_circle(
				(bank_lat, bank_lng), (work_lat, work_lng)).meters
		home_bank_vec = (bank_lat - home_lat, bank_lng - home_lng)
		home_work_vec = (work_lat - home_lat, work_lng - home_lng)
		angle_sign = (
				home_work_vec[0] * home_bank_vec[1] -
				home_work_vec[1] * home_bank_vec[0])
		try:
			angle_value = math.acos(
					(home_bank_dst ** 2 + home_work_dst ** 2 - bank_work_dst ** 2) /
					(2 * home_bank_dst * home_work_dst))
		except:
			angle_value = math.nan

		df.set_value(idx, 'dist_fact_branch', home_bank_dst)
		df.set_value(idx, 'dist_fact_wrk', home_work_dst)
		df.set_value(idx, 'dist_wrk_branch', bank_work_dst)
		df.set_value(
				idx, 'work_home_bank_angle_rad', math.copysign(angle_value, angle_sign))

	channel = grpc.insecure_channel(args.dmm_url, grpc_options)
	stub = DataMartManagerStub(channel)

	for target in ['fact', 'wrk']:
		request = MakeDataMartRequest()
		data = create_datamart_from_df(df)
		request.data.CopyFrom(data)
		request.latitude_column = list(df.columns).index('%s_lat' % target)
		request.longitude_column = list(df.columns).index('%s_lng' % target)
		request.prefix = '%s_' % target
		radii_table = request.tables.add()
		radii_table.table_name = 'radii.bank'
		radii_table.radii.extend(args.radii)
		request.return_mart = True
		logging.debug(
				'Sending request to DMManager: attaching radii for %s' % target)
		response = stub.MakeDataMart(request)
		if response.error != 0:
			logging.error(response.comment)
			raise RuntimeError('Failed to execute request to DMManager')
		df = create_df_from_datamart(response.data)

		df['banks_closer_to_%s' % target] = [0] * len(df)
		for idx, row in df.iterrows():
			dist = row['dist_%s_branch' % target]
			dist = max([r for r in args.radii if r <= dist] + [max(args.radii)])
			df.set_value(
					idx, 'banks_closer_to_%s' % target,
					row['%s_radii.bank_%d' % (target, dist)])

	logging.debug('Attaching average sqm price')
	engine = sqlalchemy.create_engine(
			'postgres://%s:%s@%s:%s/%s' % (
				args.dbuser, args.dbpass, args.dbhost, args.dbport, args.dbname))

	price_df = pandas.read_sql(
			sql=(
				'SELECT city_id, square_id, square_meter_price FROM '
				'punker.square_meter_price_full;'),
			con=engine)

	df = pandas.merge(
			df, price_df, how='left',
			left_on=('fact_grid_id', 'fact_square_id'),
			right_on=('city_id', 'square_id'))
	df.drop(['city_id', 'square_id'], axis=1, inplace=True)
	df.drop(['fact_grid_id', 'fact_square_id'], axis=1, inplace=True)
	df.drop(['wrk_grid_id', 'wrk_square_id'], axis=1, inplace=True)
	logging.debug('Geoscore done')
	return df


def main():
	logging.basicConfig(
			level=logging.DEBUG,
			format='%(asctime)s %(thread)s %(threadName)s %(levelname)s: %(message)s')
	parser = argparse.ArgumentParser(
			description='Tool for creating data marts about competitors in locality',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)

	parser.add_argument('--dbuser', type=str, default='marketinglogic',
			help='DB user name')
	parser.add_argument('--dbhost', type=str, default='127.0.0.1',
			help='DB address')
	parser.add_argument('--dbport', type=str, default='5432', help='DB port')
	parser.add_argument('--dbname', type=str, default='mldata', help='DB name')
	parser.add_argument('--dbpass', type=str, required=True, help='DB password')

	parser.add_argument('--input_file', type=str, required=True,
			help='Input CSV file')
	parser.add_argument('--sep', type=str, default=',', help='CSV separator')

	parser.add_argument('--radii', type=str, required=True,
			help='Comma separated list of radii to fetch')

	# parser.add_argument('--output_table', type=str, default=None,
	#     help='Output table')
	parser.add_argument('--output_file', type=str, required=True,
			help='Output file')

	parser.add_argument('--dmm_url', type=str, default='127.0.0.1:55556',
			help='Address of geocoder service')

	parser.add_argument('--max_request_size', type=int, default=2000,
			help='Max gRPC request size in MBs')
	args = parser.parse_args()

	df = do_geoscore(args)
	df.to_csv(args.output_file, index=False)
	print(df.head())

if __name__ == '__main__':
	main()
