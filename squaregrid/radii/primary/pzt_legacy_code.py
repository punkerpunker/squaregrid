import functools
import gc
from geopy.distance import great_circle
import logging
from math import cos
from multiprocessing import Pool
import numpy
import pandas
import tempfile

from processing.geocoder import geocode

def make_pzt(df_addresses, request, engine, cores):
	with tempfile.NamedTemporaryFile() as out_file:
		df_spark, df_objects = get_dataframes(
				df_addresses, request.address_column, request.distance, engine, cores)
		column_names_objects = {'email':'email_pzt',
				'site':'web_site_pzt',
				'gc_address':'address_pzt',
				'name_standardized':'org_name_pzt',
				'phone_standardized':'phone_pzt'}
		column_names_spark = {'elektronnyj_adres':'email_pzt',
				'sajt_v_seti_internet':'web_site_pzt',  # 'Web-адрес',
				'address':'address_pzt',
				'standardized_org_name':'org_name_pzt',
				'phone_corrected':'phone_pzt'}
		phone_web_email_delimiter = ';'
		df_objects, df_spark = prepare_files(
				column_names_objects, column_names_spark,
				df_spark=df_spark, df_objects=df_objects)
		matching_objects(df_objects, df_spark, request, out_file.name, cores)
		out_file.seek(0)
		final_df = correcting_csv(out_file, request.rank)
		return final_df


def closest_objects_finder(distance, df_addresses, df):
	radius_km = distance
	for index, row in df.iterrows():
		gc_lat = float(df.get_value(index, 'gc_lat'))
		gc_lng = float(df.get_value(index, 'gc_lng'))
		latmax = gc_lat + 1/110.574*radius_km
		latmin = gc_lat - 1/110.574*radius_km
		longmax = gc_lng + abs(1/111.320*radius_km*cos(gc_lat))
		longmin = gc_lng - abs(1/111.320*radius_km*cos(gc_lng))
		subset = df_addresses.loc[(df_addresses['gc_lat'] < latmax) &
				(df_addresses['gc_lat'] > latmin) &
				(df_addresses['gc_lng'] < longmax) &
				(df_addresses['gc_lng'] > longmin)]
		for index_realty, row_realty in subset.iterrows():
			subset.set_value(
					index_realty, 'distance',
					great_circle(
						(gc_lat, gc_lng), (row_realty.gc_lat, row_realty.gc_lng)).meters)
		if subset.shape[0] != 0:
			if subset.shape[0] < 1:
				k = subset.shape[0]
			else:
				k = 1
			subset = subset.sort_values(['distance'], ascending=[True])
			subset = subset.head(k)
			count = 0
			for index_subset, row_subset in subset.iterrows():
				count += 1
				df.set_value(index, 'closest_office_'+str(count), str(row_subset.office_name))
				try:
					df.set_value(index, 'distance_to_'+str(count), round(row_subset.distance),0)
				except:
					pass
	df.dropna(subset=['closest_office_1'], how='all', inplace=True)
	return df

def parallelize_dataframe(df, func, cores):
	num_partitions=80
	df_split = numpy.array_split(df, num_partitions)
	pool = Pool(cores, maxtasksperchild=1)
	df = pandas.concat(pool.map(func, df_split), ignore_index=True)
	pool.close()
	pool.join()
	return df


def matching_objects(df_objects, df_spark, request, output_tmp_file, cores):
	count = 0
	for g,chunk in df_objects.groupby(
			numpy.arange(len(df_objects))//request.chunk_size):
		count += 1
		df = parallelize_dataframe(
				chunk,
				functools.partial(matching, request.rank, df_spark),
				cores)
		df = df.sort_values(['match_rank'], ascending=True)
		df.drop_duplicates(subset=['id'], keep='first', inplace=True)
		df.to_csv(output_tmp_file, mode='a', index=False, header=(count == 1))
		logging.debug(
				'done: %d out ouf %d' % (
					count * request.chunk_size, df_objects.shape[0]))


def prepare_files(
		column_names_objects, column_names_spark, df_spark, df_objects):
	df_spark.rename(columns=column_names_spark, inplace=True)
	df_objects.rename(columns=column_names_objects, inplace=True)
	df_spark.phone_pzt.fillna('1', inplace=True)
	df_spark.email_pzt.fillna('1', inplace=True)
	df_objects.phone_pzt.fillna('2', inplace=True)
	df_objects.email_pzt.fillna('2', inplace=True)
	df_objects.web_site_pzt.fillna('2', inplace=True)
	return df_objects, df_spark


def get_dataframes(df_addresses, address_column, distance, engine, cores):
	df_addresses['office_name'] = df_addresses[address_column]
	line = (
			'select objects_yandex_organization_20170806.*, '
			'objects_yandex_rubric_20170806.name as rubric_name, '
			'pzt_phone.phone_standardized, '
			'pzt_email.email, razdel_name as razdel, podrazdel_name as podrazdel '
			'from raw_data.objects_yandex_organization_20170806 '
			'left join raw_data.objects_yandex_organization_rubric_20170806 '
			'on objects_yandex_organization_rubric_20170806.organization_id = objects_yandex_organization_20170806.id '
			'left join raw_data.objects_yandex_rubric_20170806 '
			'on objects_yandex_rubric_20170806.id = objects_yandex_organization_rubric_20170806.rubric_id '
			'left join punker_test_schema.pzt_email '
			'on pzt_email.organization_id = objects_yandex_organization_20170806.id ' \
			'left join punker_test_schema.pzt_phone '
			'on pzt_phone.organization_id = objects_yandex_organization_20170806.id '
			'left join metadata.rubrics_category_levels '
			'on objects_yandex_rubric_20170806.name = rubrics_category_levels.rubric_name '
			'where gc_lat is not null and gc_lng is not null and  ')
	for index, row in df_addresses.iterrows():
		if row.city!=None:
			line += 'gc_city =\''+row.city +'\' or '
		else:
			line += 'gc_state = \''+row.state +'\' or '
	line = line.rstrip(' or ')
	df_objects_full = pandas.read_sql_query(line, engine)
	df_objects_full[['gc_lat', 'gc_lng']] = (
			df_objects_full[['gc_lat', 'gc_lng']].apply(
				pandas.to_numeric, errors='ignore'))
	df_objects = parallelize_dataframe(
			df_objects_full,
			functools.partial(closest_objects_finder, distance, df_addresses),
			cores)
	logging.debug('objects ready!')
	del df_objects_full
	line = 'select * from companies.spark_new where '
	for index, row in df_addresses.iterrows():
		if row.city!=None:
			line += 'city =\''+row.city +'\' or '
		else:
			line += 'state = \''+row.state +'\' or '
	line = line.rstrip(' or ')
	df_spark = pandas.read_sql_query(line, engine)
	logging.debug('spark ready!')
	return df_spark, df_objects


def correcting_csv(output_dir, match_rank):
	df = pandas.read_csv(output_dir, error_bad_lines=False)
	df = df.sort_values(['match_rank'], ascending=True)
	df.drop_duplicates(subset=['id'], keep='first', inplace=True)
	logging.debug('correcting_csv begin')
	columns_to_rename = {
			'_2015_vyruchka_ot_prodazhi_za_minusom_nds_aktsizov_ed_rub':'Выручка компании 2015',
			'_2014_vyruchka_ot_prodazhi_za_minusom_nds_aktsizov_ed_rub':'Выручка компании 2014',
			'_2016_srednespisochnaja_chislennost_rabotnikov':'Среднесписочная численность работников',
			'address':'Адрес','closest_office_1': 'Ближайший офис',
			'data_registratsii':'Дата регистрации',
			'distance':'Расстояние до ближайшего офиса (м)','email_pzt_spark':'Электронный адрес',
			'distance_to_1': 'Расстояние до ближайшего офиса (м)',
			'forma_sobstvennosti':'Форма собственности','hours':'Часы работы объекта',
			'kod_nalogoplatel_schika':'ИНН компании',
			'kod_prichiny_postanovki_na_uchet':'Код причины постановки на учёт',
			'naimenovanie':'Название компании краткое',
			'naimenovanie_polnoe':'Название компании полное',
			'payment_by_credit_card':'Возможность оплаты банковскими картами',
			'telefon':'Номера телефонов','podrazdel':'Подраздел','razdel':'Раздел',
			'razmer_kompanii':'Размер компании',
			'registratsionnyj_nomer':'Регистрационный номер','rubric_name':'Категория',
			'rukovoditel_dolzhnost':'Должность руководителя',
			'rukovoditel_fio':'ФИО руководителя компании',
			'rukovoditel_inn':'ИНН руководителя',
			'ustavnyj_kapital':'Уставный капитал компании',
			'vid_dejatel_nosti_otrasl':'Вид деятельности компании',
			'vozrast_kompanii':'Возраст компании','web_site_pzt_objects':'Веб-Сайт',
			'match_rank':'Качество соответстия данных в процентах','name':'Название объекта',
			'organizatsionno_pravovaja_forma':'Организационно правовая форма компании',
			"gc_quality": "Точность определения адреса",
			"gc_lng": "Долгота",
			"gc_lat": "Широта"}
	df.rename(columns=columns_to_rename, inplace=True)

	quality_to_rename = {
		'exact': "Точно",
		'street': "До уровня улицы",
		'number': "До уровня дома",
		'near': "Погрешность 0-300 м",
		'other': "Другое"
	}
	df['Качество соответстия данных в процентах'] = (
			df['Качество соответстия данных в процентах'].astype(
				float, errors='ignore'))
	df = df.replace({"Точность определения адреса": quality_to_rename})
	df = df.loc[df['Качество соответстия данных в процентах'] < match_rank+1]
	df['Качество соответстия данных в процентах'].replace(1,95, inplace=True)
	df['Качество соответстия данных в процентах'].replace(2,90, inplace=True)
	df['Качество соответстия данных в процентах'].replace(3,87, inplace=True)
	df['Качество соответстия данных в процентах'].replace(4,85, inplace=True)
	df['Качество соответстия данных в процентах'].replace(5,80, inplace=True)
	df['Качество соответстия данных в процентах'].replace(6,75, inplace=True)
	df['Качество соответстия данных в процентах'].replace(7,70, inplace=True)
	df['Качество соответстия данных в процентах'].replace(8,65, inplace=True)
	df['Качество соответстия данных в процентах'].replace(9,60, inplace=True)
	df['Качество соответстия данных в процентах'].replace(10,50, inplace=True)
	df['Качество соответстия данных в процентах'].replace(11,45, inplace=True)
	df['Качество соответстия данных в процентах'].replace(12,40, inplace=True)
	df['Качество соответстия данных в процентах'].replace(13,35, inplace=True)
	df['Качество соответстия данных в процентах'].replace(14,30, inplace=True)
	df['Качество соответстия данных в процентах'].replace(15,20, inplace=True)
	df['Качество соответстия данных в процентах'].replace(16,0, inplace=True)

	df['Сгруппированное расстояние'] = ''
	for index, row in df.iterrows():
		if (0 < row['Расстояние до ближайшего офиса (м)'] and
				row['Расстояние до ближайшего офиса (м)'] < 500):
			df.loc[index,'Сгруппированное расстояние'] = '0 - 500'
		elif (500 < row['Расстояние до ближайшего офиса (м)'] and
				row['Расстояние до ближайшего офиса (м)'] < 1000):
			df.loc[index,'Сгруппированное расстояние'] = '500 - 1000'
		elif (1000 < row['Расстояние до ближайшего офиса (м)'] and
				row['Расстояние до ближайшего офиса (м)'] < 2000):
			df.loc[index,'Сгруппированное расстояние'] = '1000 - 2000'
		elif (2000 < row['Расстояние до ближайшего офиса (м)'] and
				row['Расстояние до ближайшего офиса (м)'] < 3000):
			df.loc[index, 'Сгруппированное расстояние'] = '2000 - 3000'
	df = df[
			['Название объекта', 'Адрес', 'Название компании краткое',
				'Выручка компании 2014', 'Выручка компании 2015', 'Номера телефонов',
				'ФИО руководителя компании', 'Веб-Сайт', 'Электронный адрес',
				'Ближайший офис', 'Расстояние до ближайшего офиса (м)',
				'Сгруппированное расстояние', 'Качество соответстия данных в процентах',
				'Раздел', 'Подраздел', 'Категория', 'Часы работы объекта',
				'Возможность оплаты банковскими картами', 'Точность определения адреса',
				'Широта', 'Долгота', 'Название компании полное', 'Возраст компании',
				'Дата регистрации', 'Размер компании', 'ИНН компании',
				'Регистрационный номер', 'Код причины постановки на учёт',
				'Уставный капитал компании', 'Вид деятельности компании',
				'Среднесписочная численность работников', 'Форма собственности',
				'Организационно правовая форма компании', 'Должность руководителя',
				'ИНН руководителя', 'facebook', 'vkontakte', 'instagram',
				'odnoklassniki']]
	df['Выручка компании 2014'] = (
			df['Выручка компании 2014'].astype(str).str.rstrip('.0'))
	df['Выручка компании 2015'] = (
			df['Выручка компании 2015'].astype(str).str.rstrip('.0'))
	df['ИНН компании'] = df['ИНН компании'].astype(str).str.rstrip('.0')
	df['ИНН руководителя'] = df['ИНН руководителя'].astype(str).str.rstrip('.0')
	df['Уставный капитал компании'] = (
			df['Уставный капитал компании'].astype(str).str.rstrip('.0'))
	df['Регистрационный номер'] = (
			df['Регистрационный номер'].astype(str).str.rstrip('.0'))
	logging.debug('correcting_csv end')
	return df


# ugh ._.
def matching(match_rank, df_spark, df_objects):
	phone_web_email_delimiter = ';'
	df_founded_objects = pandas.DataFrame(data=None, columns=df_objects.columns)
	df_spark_empty = pandas.DataFrame(data=None, columns=df_spark.columns)
	df_spark_empty['join_col'] = 2
	df_founded_objects = df_founded_objects.merge(
			df_spark_empty, how='left', on='address_pzt',
			suffixes=('_objects','_spark'))
	df_good_objects = pandas.DataFrame(data=None, columns=df_founded_objects.columns)
	df_good_objects['match_rank'] = 0
	for index, row in df_objects.iterrows():
		gc.collect()
		df_spark_addr = df_spark.loc[df_spark.address_pzt == row.address_pzt]
		df_spark_name = df_spark.loc[(df_spark.org_name_pzt == row.org_name_pzt)]

		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		# if you don't need rank more then ten you should comment two df's below
		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

		if match_rank>10:
			if df_spark_addr.shape[0] == 0 and df_spark_name.shape[0] == 0:
				try:
					df_spark_phone = df_spark.loc[
							df_spark.phone_pzt.str.contains(
								'|'.join(row.phone_pzt.split(
									phone_web_email_delimiter)), na=False)]
					df_spark_site = df_spark.loc[
							(df_spark.web_site_pzt.str.contains(
								'|'.join(row.web_site_pzt.split(phone_web_email_delimiter)),
								na=False)) |
							(df_spark.email_pzt.str.contains(
								'|'.join(row.email_pzt.split(phone_web_email_delimiter)),
								na=False))]
				except:
					print ('bad: ' + str(index))
					continue
		#matching ranks 1, 2, 3, 5, 6, 7 , 9, 15
		if df_spark_addr.shape[0] != 0:
			try:
				df_spark_phone = df_spark_addr.loc[
						df_spark_addr.phone_pzt.str.contains(
							'|'.join(row.phone_pzt.split(phone_web_email_delimiter)),
							na=False)]
				df_spark_name = df_spark_addr.loc[
						df_spark_addr.org_name_pzt == row.org_name_pzt]
				df_spark_site = (
						df_spark_addr.loc[
							(df_spark_addr.web_site_pzt.str.contains(
								'|'.join(row.web_site_pzt.split(phone_web_email_delimiter)),
								na=False)) |
							(df_spark_addr.email_pzt.str.contains(
								'|'.join(row.email_pzt.split(phone_web_email_delimiter)),
								na=False))])
			except:
				continue
			if df_spark_phone.shape[0] != 0:
				df_spark_name = df_spark_phone.loc[
						df_spark_phone.org_name_pzt == row.org_name_pzt]
				if df_spark_name.shape[0] != 0:
					df_spark_site = df_spark_name.loc[
							(df_spark_name.web_site_pzt.str.contains(
								'|'.join(row.web_site_pzt.split(phone_web_email_delimiter)),
								na=False)) |
							(df_spark_name.email_pzt.str.contains(
								'|'.join(row.email_pzt.split(phone_web_email_delimiter)),
								na=False))]

					if df_spark_site.shape[0] != 0:
						df_founded_objects = pandas.DataFrame(
								data=None, columns=df_objects.columns)
						df_founded_objects.loc[index, :] = df_objects.loc[index, :]
						df_founded_objects['match_rank'] = 1
						df_founded_objects = (
								df_founded_objects.merge(
									df_spark_site, how='left', on=['address_pzt','org_name_pzt'],
									suffixes=('_objects','_spark')))
						df_good_objects = df_good_objects.append(df_founded_objects)
					else:
						df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
						df_founded_objects.loc[index, :] = df_objects.loc[index, :]
						df_founded_objects['match_rank'] = 5
						df_founded_objects = (
							df_founded_objects.merge(
								df_spark_name, how='left', on=['address_pzt','org_name_pzt'],
								suffixes=('_objects','_spark')))
						df_good_objects = df_good_objects.append(df_founded_objects)
				else:
					df_spark_site = df_spark_phone.loc[
						(df_spark_phone.web_site_pzt.str.contains(
							'|'.join(
								row.web_site_pzt.split(phone_web_email_delimiter)), na=False)) |
						(df_spark_phone.email_pzt.str.contains(
							'|'.join(row.email_pzt.split(phone_web_email_delimiter)),
							na=False))]
					if df_spark_site.shape[0] != 0:
						df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
						df_founded_objects.loc[index, :] = df_objects.loc[index, :]
						df_founded_objects['match_rank'] = 3
						df_founded_objects = (
							df_founded_objects.merge(
								df_spark_site, how='left', on='address_pzt',
								suffixes=('_objects','_spark')))
						df_good_objects = df_good_objects.append(df_founded_objects)
					else:
						df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
						df_founded_objects.loc[index, :] = df_objects.loc[index, :]
						df_founded_objects['match_rank'] = 9
						df_founded_objects = (
							df_founded_objects.merge(
								df_spark_phone, how='left', on='address_pzt',
								suffixes=('_objects','_spark')))
						df_good_objects = df_good_objects.append(df_founded_objects)
			elif df_spark_name.shape[0] != 0:
				df_spark_site = (
					df_spark_name.loc[
						(df_spark_name.web_site_pzt.str.contains(
							'|'.join(row.web_site_pzt.split(phone_web_email_delimiter)),
							na=False)) |
						(df_spark_name.email_pzt.str.contains(
							'|'.join(row.email_pzt.split(phone_web_email_delimiter)),
							na=False))])
				if df_spark_site.shape[0] !=0:
					df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
					df_founded_objects.loc[index, :] = df_objects.loc[index, :]
					df_founded_objects['match_rank'] = 2
					df_founded_objects = (
							df_founded_objects.merge(
								df_spark_site, how='left', on='address_pzt',
								suffixes=('_objects', '_spark')))

				else:
					df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
					df_founded_objects.loc[index, :] = df_objects.loc[index, :]
					df_founded_objects['match_rank'] = 7
					df_founded_objects = df_founded_objects.merge(
							df_spark_name, how='left', on='address_pzt',
							suffixes=('_objects', '_spark'))
				df_good_objects = df_good_objects.append(df_founded_objects)
			elif df_spark_site.shape[0] != 0:
				df_founded_objects = pandas.DataFrame(
						data=None, columns=df_objects.columns)
				df_founded_objects.loc[index, :] = df_objects.loc[index, :]
				df_founded_objects['match_rank'] = 6
				df_founded_objects = df_founded_objects.merge(
						df_spark_site, how='left', on='address_pzt',
						suffixes=('_objects','_spark'))
				df_good_objects = df_good_objects.append(df_founded_objects)
			else:
				df_founded_objects = pandas.DataFrame(data=None, columns=df_objects.columns)
				df_founded_objects.loc[index, :] = df_objects.loc[index, :]
				df_founded_objects['match_rank'] = 15
				df_founded_objects = df_founded_objects.merge(
						df_spark_addr, how='left', on='address_pzt',
						suffixes=('_objects', '_spark'))
				df_good_objects = df_good_objects.append(df_founded_objects)
		#matching ranks 4, 8, 10, 14
		elif df_spark_name.shape[0] != 0:
			df_spark_phone = df_spark_name.loc[
					df_spark_name.phone_pzt.str.contains(
						'|'.join(row.phone_pzt.split(phone_web_email_delimiter)), na=False)]
			df_spark_site = df_spark_name.loc[
					(df_spark_name.web_site_pzt.str.contains(
						'|'.join(
							row.web_site_pzt.split(phone_web_email_delimiter)),
						na=False)) |
					(df_spark_name.email_pzt.str.contains(
						'|'.join(row.email_pzt.split(phone_web_email_delimiter)),
						na=False))]
			if df_spark_phone.shape[0] != 0:
				df_spark_site = df_spark_phone.loc[
						(df_spark_phone.web_site_pzt.str.contains(
							'|'.join(row.web_site_pzt.split(phone_web_email_delimiter)),
							na=False)) |
						(df_spark_phone.email_pzt.str.contains(
							'|'.join(row.email_pzt.split(phone_web_email_delimiter)),
							na=False))]
				if df_spark_site.shape[0] != 0:
					df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
					df_founded_objects.loc[index, :] = df_objects.loc[index, :]
					df_founded_objects['match_rank'] = 4
					df_founded_objects = df_founded_objects.merge(
							df_spark_site, how='left', on='org_name_pzt',
							suffixes=('_objects', '_spark'))
					df_good_objects = df_good_objects.append(df_founded_objects)
				else:
					df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
					df_founded_objects.loc[index, :] = df_objects.loc[index, :]
					df_founded_objects['match_rank'] = 10
					df_founded_objects = df_founded_objects.merge(
							df_spark_phone, how='left', on='org_name_pzt',
							suffixes=('_objects', '_spark'))
					df_good_objects = df_good_objects.append(df_founded_objects)
			elif df_spark_site.shape[0] !=0:
				df_founded_objects = pandas.DataFrame(data=None, columns=df_objects.columns)
				df_founded_objects.loc[index, :] = df_objects.loc[index, :]
				df_founded_objects['match_rank'] = 8
				df_founded_objects = df_founded_objects.merge(
						df_spark_site, how='left', on='org_name_pzt',
						suffixes=('_objects', '_spark'))
				df_good_objects = df_good_objects.append(df_founded_objects)
			else:
				df_founded_objects = pandas.DataFrame(
						data=None, columns=df_objects.columns)
				df_founded_objects.loc[index, :] = df_objects.loc[index, :]
				df_founded_objects['match_rank'] = 14
				df_founded_objects = df_founded_objects.merge(
						df_spark_name, how='left', on='org_name_pzt',
						suffixes=('_objects', '_spark'))
				df_good_objects = df_good_objects.append(df_founded_objects)
		#matching ranks 11, 12
		if match_rank > 10:
			if df_spark_site.shape[0] != 0:
				df_spark_phone = df_spark_site.loc[
						df_spark_site.phone_pzt.str.contains(
							'|'.join(row.phone_pzt.split(phone_web_email_delimiter)),
							na=False)]
				if df_spark_phone.shape[0]!=0:
					df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
					df_founded_objects.loc[index, :] = df_objects.loc[index, :]
					df_founded_objects['match_rank'] = 11
					df_founded_objects['join_col'] = 1
					df_spark_phone['join_col'] =1
					df_founded_objects = df_founded_objects.merge(
							df_spark_phone, how='left', suffixes=('_objects', '_spark'),
							on='join_col')
					df_good_objects = df_good_objects.append(df_founded_objects)
				else:
					df_founded_objects = pandas.DataFrame(
							data=None, columns=df_objects.columns)
					df_founded_objects.loc[index, :] = df_objects.loc[index, :]
					df_founded_objects['match_rank'] = 12
					df_founded_objects['join_col'] = 1
					df_spark_site['join_col'] = 1
					df_founded_objects = df_founded_objects.merge(
							df_spark_site, how='left', suffixes=('_objects', '_spark'),
							on='join_col')
					df_good_objects = df_good_objects.append(df_founded_objects)
			#matching rank 13
			elif df_spark_phone.shape[0]!=0:
				df_founded_objects = pandas.DataFrame(data=None, columns=df_objects.columns)
				df_founded_objects.loc[index, :] = df_objects.loc[index, :]
				df_founded_objects['match_rank'] = 13
				df_founded_objects['join_col'] = 1
				df_spark_phone['join_col'] = 1
				df_founded_objects = df_founded_objects.merge(df_spark_phone,
						how='left', suffixes=('_objects', '_spark'), on='join_col')
				df_good_objects = df_good_objects.append(df_founded_objects)
			else:
				df_founded_objects = pandas.DataFrame(data=None, columns=df_objects.columns)
				df_founded_objects.loc[index, :] = df_objects.loc[index, :]
				df_founded_objects['match_rank'] = 16
				df_founded_objects['join_col'] = 2
				df_founded_objects = df_founded_objects.merge(
						df_spark_empty, suffixes=('_objects','_spark'), on = 'join_col',
						how='left')
				df_good_objects = df_good_objects.append(df_founded_objects)
	return df_good_objects
