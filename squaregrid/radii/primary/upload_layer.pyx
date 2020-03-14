from libcpp.vector cimport vector
from libcpp.utility cimport pair

from grids.pywrap_grid_metadata cimport EnumerateGridCells
import time
import argparse
import logging
import pandas
import requests
import sqlalchemy

def main():
	logging.basicConfig(
			level=logging.DEBUG,
			format='%(asctime)s %(thread)s %(threadName)s %(levelname)s: %(message)s')
	parser = argparse.ArgumentParser(
			description='Upload layer into atlas',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)

	parser.add_argument('--url', type=str,
			default='https://demo.marketing-logic.ru/develop/api/csv-to-grid',
			help='Atlas API address')
	parser.add_argument('--username', type=str, default='admin', help='Username')
	parser.add_argument('--password', type=str, default='admin1', help='Password')
	parser.add_argument('--access_token', type=str, default='', help='access_token')
	parser.add_argument('--project_title', type=str, required=True,
			help='Project title')
	parser.add_argument('--layer_title', type=str, required=True,
			help='Layer title')
	parser.add_argument('--city_id', type=str, required=True,
			help='City id')
	parser.add_argument('--float_digits', type=str, help='Num digits after comma')
	parser.add_argument('--group', type=str, help='Name of group')
	parser.add_argument('--input_file', type=str, default=None, help='CSV file')
	parser.add_argument('--sep', type=str, default=',', help='CSV separator')
	parser.add_argument('--id_col', type=str, default=None, help='Id column')
	parser.add_argument('--data_col', type=str, default=None, help='Data column')

	parser.add_argument(
			'--input_query', type=str, default=None,
			help='SQL query yielding (square_id, value)')
	parser.add_argument('--dbuser', type=str, default='marketinglogic',
			help='DB user name')
	parser.add_argument('--dbhost', type=str, default='127.0.0.1',
			help='DB address')
	parser.add_argument('--dbport', type=str, default='5432', help='DB port')
	parser.add_argument('--dbname', type=str, default='mldata', help='DB name')
	parser.add_argument('--dbpass', type=str, default=None, help='DB password')

	parser.add_argument('--output_file', type=str, required=True, help='out file')
	parser.add_argument('--out_sep', type=str, default=',', help='CSV separator')

	parser.add_argument('--grid_halfsize', type=int, required=True,
			help='Grid half-size')
	parser.add_argument('--legacy_ids', type=bool, default=False,
			help='Use legacy square ids?')
	args = parser.parse_args()

	cdef int n = 2 * int(args.grid_halfsize)
	cdef int x, y, i
	cdef vector[pair[int, int]] cells = EnumerateGridCells(args.grid_halfsize)
	cdef vector[vector[float]] data = vector[vector[float]](n, vector[float](n))

	if args.input_file is not None:
		df = pandas.read_csv(args.input_file, sep=args.sep)
	elif args.input_query is not None:
		if args.dbpass is None:
			raise ValueError('Specify --dbpass if using --input_query')
		engine = sqlalchemy.create_engine(
				'postgres://%s:%s@%s:%s/%s' % (args.dbuser, args.dbpass, args.dbhost,
					args.dbport, args.dbname))
		df = pandas.read_sql(args.input_query, engine)
		if len(df.columns) != 2:
			raise ValueError('Query yield wrong number of fields')
		args.id_col = df.columns[0]
		args.data_col = df.columns[1]
	else:
		raise ValueError('One of --input_file or --input_query must be specified')

	for cur_id, cur_value in zip(df[args.id_col], df[args.data_col]):
		if not args.legacy_ids:
			x = cells[cur_id].first
			y = cells[cur_id].second
		else:
			x = cur_id // n
			y = cur_id % n
		# invert latitude axis
		data[n - 1 - x][y] = cur_value

	with open(args.output_file, 'w') as f:
		for i in range(n):
			f.write(args.out_sep.join(map(lambda s: '%.3f' % s, data[i])) + '\n')

	files = {'data_file': open(args.output_file, 'rb')}
	if args.access_token == '':
		post_args = {
				'username': args.username,
				'password': args.password,
				'project_title': args.project_title,
				'layer_title': args.layer_title,
				'city_id': args.city_id,
				'float':args.float_digits,
				'group':args.group,
		}
	else:
		post_args = {
				'access_token': args.access_token,
				'project_title': args.project_title,
				'layer_title': args.layer_title,
				'city_id': args.city_id,
				'float':args.float_digits,
				'group':args.group,
		}
	print(post_args)
	print('post query')
	time.sleep(10)
	session = requests.Session()
	session.verify = False
	r = session.post(args.url, data=post_args, files=files)
	print(r.text)

if __name__ == '__main__':
	main()
