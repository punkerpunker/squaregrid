import sqlalchemy
import os
import pandas

def main():
	engine = sqlalchemy.create_engine(
			'postgres://marketinglogic:marketinglogic1@148.251.45.229/geomining')
	all_cats = list(engine.execute(
			'SELECT ak_razdel, ak_podrazdel FROM ak_objects '
			'WHERE ak_razdel IS NOT NULL AND ak_podrazdel IS NOT NULL '
			'GROUP BY ak_razdel, ak_podrazdel '
			'ORDER BY ak_razdel, ak_podrazdel;'))
	df = pandas.DataFrame({
		'ak_razdel': [x[0] for x in all_cats],
		'al_podrazdel': [x[1] for x in all_cats],
	})
	df.to_csv('bin_categories.csv', index=True)
	print('%d categories' % len(all_cats))
	for i, (cat, sub_cat) in enumerate(all_cats):
		print(cat, sub_cat)
		os.system(" ".join([
			'./primary/bin_radii', '--dbpass="marketinglogic1"',
			'--dbhost=148.251.45.229', '--dbname=geomining',
			'--output_table=precalculated_radii.objects_table_%d' % i,
			'--data_query="SELECT lat, lng from ak_objects '
			'WHERE ak_razdel = \'%s\' AND ak_podrazdel = \'%s\'"' % (cat, sub_cat),
			'--threads=1', '--action=sum'
		]))


if __name__ == '__main__':
	main()
