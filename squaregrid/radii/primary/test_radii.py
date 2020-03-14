import argparse
import sqlalchemy


class DBTestQuery:
	def __init__(self, query, comment):
		self.query = query
		self.comment = comment


def main():
	parser = argparse.ArgumentParser(
			description='Compare proto vs table in database',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('--dbuser', type=str, default='marketinglogic',
			help='DB user name')
	parser.add_argument('--dbhost', type=str, default='127.0.0.1',
			help='DB address')
	parser.add_argument('--dbport', type=str, default='5432', help='DB port')
	parser.add_argument('--dbname', type=str, default='mldata', help='DB name')
	parser.add_argument('--dbpass', type=str, default=None, help='DB password')
	args = parser.parse_args()

	engine = sqlalchemy.create_engine(
			'postgres://%s:%s@%s:%s/%s' % (args.dbuser, args.dbpass, args.dbhost,
				args.dbport, args.dbname))

	queries = [
			DBTestQuery(
				'SELECT '
				'(SELECT _0 FROM radii.flats WHERE square_id = 4015 AND city_id = 20)'
				' > '
				'(SELECT _0 FROM radii.flats WHERE square_id = 44491 AND city_id = 20)',
				'Some Moscow square > Losiniy Ostrov'),
			DBTestQuery(
				'SELECT '
				'(SELECT _0 + _100 + _200 + _300 + _400 FROM radii.flats'
				' WHERE square_id = 4015 AND city_id = 20)'
				' > '
				'(SELECT _0 + _100 + _200 + _300 + _400 FROM radii.flats'
				' WHERE square_id = 44491 AND city_id = 20)',
				'Some Moscow square (r500) > Losiniy Ostrov (r500)'),
			DBTestQuery(
				'SELECT '
				'(SELECT _0 FROM radii.flats WHERE square_id = 4015 AND city_id = 20)'
				' > '
				'(SELECT _0 FROM radii.flats WHERE square_id = 185033'
				' AND city_id = 20)',
				'Some Moscow square > Odintsovo'),
			DBTestQuery(
				'SELECT '
				'(SELECT _0 + _100 + _200 + _300 + _400 FROM radii.flats'
				' WHERE square_id = 4015 AND city_id = 20)'
				' > '
				'(SELECT _0 + _100 + _200 + _300 + _400 FROM radii.flats'
				' WHERE square_id = 185033 AND city_id = 20)',
				'Some Moscow square (r500) > Odintsovo (r500)'),
	]

	for q in queries:
		res = list(engine.execute(q.query))
		assert len(res) == 1, 'Query should return one boolean value'
		assert res[0][0], q.comment

if __name__ == '__main__':
	main()
