import psycopg2 as ps
import sys
import os
import getpass
import pandas as pd
from subprocess import check_call
from pgbase.db.table import Table
from pgbase.db.engine import DB, Loger
from squaregrid.radii.location import get_build_location


class Radii(Table):
    def __init__(self, category='', radii_schema='radii', rubrikator_schema='rubrikator',
                 new=False, yandex=True, new_eng='', new_rus='', new_elements=(), new_names=(),
                 names_denial=False, elements_denial=False, inplace=False, db=None):
        if not db:
            self.db = DB()
        else:
            self.db = db
        self.engine = self.db.engine
        self.category = category
        self.info_loger = Loger('logs.radii_calculations_log', self.db)
        self.radii_schema = radii_schema
        self.rubrikator_schema = rubrikator_schema
        self.names_denial = names_denial
        self.elements_denial = elements_denial
        if new:
            self.elements = new_elements
            self.names = new_names
            if yandex:
                self.check_elements_existance()
                self.check_names_existance()
            self.add_new_rubric_radii(new_eng, new_rus, new_elements, new_names, inplace)
            self.en_category = new_eng
            self.ru_category = new_rus
        else:
            self.category_eng_rus_handler()
            self.elements = self.get_elements()
            self.names = self.get_names()
        super(Radii, self).__init__(schema_table=self.rubrikator_schema + '.' + self.en_category, db=self.db)

    def add_new_rubric_radii(self, eng, rus, elements, names, inplace):
        assert len(eng)+len(rus)+len(elements) != 3, \
            'If you add new category, you have to specify new_eng, new_rus, new_elements '
        cur = self.db.cur

        def check_existance(eng, cur):
            cur.execute("select * from metadata.rubrics_radii where eng = '"+str(eng)+"'")
            coincidence = cur.fetchall()
            if len(coincidence) == 0:
                return False
            else:
                return True
        exists = check_existance(eng, cur)
        if exists & (not inplace):
            raise Exception('Rubric "'+eng+'" already exists! You have to specify (try with inplace=True)')
        else:
            if inplace:
                cur.execute("delete from metadata.rubrics_radii where eng = '" + str(eng) + "'")
                self.db.commit()
            insert_tuple = (eng, rus, ';'.join(elements), ','.join(names), self.elements_denial, self.names_denial)
            cur.execute("insert into metadata.rubrics_radii (eng, rus, elements, names, elements_denial, names_denial)  "
                        "values "+str(insert_tuple))
            self.db.commit()
            self.info_loger.write_to_log('is_new', 1)

    def make_check_call_string(self, data_query, table_name, radii_count):
        check_call_string = './primary/calculate_radii ' \
                            '--dbpass="tttBBB777" ' \
                            '--output_table="'+self.radii_schema+'.' + table_name + '" ' \
                            '--data_query="' + data_query + '" ' \
                            '--threads=30 ' \
                            '--action=sum ' \
                            '--radii_count='+str(radii_count)
        self.info_loger.write_to_log('output_table', self.radii_schema + '.' + table_name)
        return check_call_string

    def category_eng_rus_handler(self):
        try:
            self.ru_category = self.category
            self.en_category = self.get_eng_rubric_name_by_ru()
        except TypeError:
            try:
                self.en_category = self.category
                self.ru_category = self.get_ru_rubric_name_by_eng()
            except:
                raise Exception('No such category: "'+str(self.category)+'". If you want to add one, set new=True')

    @staticmethod
    def make_data_query(categories=(), names=(), elements_denial=False, names_denial=False):
        data_query = "select lat, lon from yandex_objects.organization as o " \
                     "left join yandex_objects.organization_rubric as o_r " \
                     "on o_r.organization_id = o.id " \
                     "left join yandex_objects.rubric as r " \
                     "on o_r.rubric_id = r.id " \
                     " where updated != 0 "
        if categories:
            if elements_denial:
                data_query += ' and r.name not in ('
            else:
                data_query += ' and r.name in ('
            for cat in categories:
                data_query += "'" + str(cat) + "',"
            data_query = data_query.rstrip(',')
            data_query += ")"
        if names:
            if names_denial:
                data_query += ' and o.name_standardized not in ('
            else:
                data_query += ' and o.name_standardized in ('
            for name in names:
                data_query += "'"+name+"',"
            data_query = data_query.rstrip(',')
            data_query += ")"
        return data_query

    def get_objects_assembly_date(self):
        cur = self.db.cur
        cur.execute("select date "
                    "from yandex_objects._info "
                    "where name = 'organization'")
        date = cur.fetchone()[0]
        return date

    def get_objects_calculation_assembly_date(self):
        cur = self.db.cur
        cur.execute("select max(date_objects_assembly) "
                    "from logs.radii_calculations_log "
                    "where function = 'calculate_radii' "
                    " and category = '"+self.en_category+"'"
                    " and done = True")
        date = cur.fetchone()[0]
        return date

    def check_elements_existance(self):
        cur = self.db.cur
        for element in self.elements:
            cur.execute("select rus from metadata.rubrics where rus = '"+element+"'")
            coincidence = cur.fetchall()
            if len(coincidence) == 0:
                raise Exception('There is no such category "'+str(element)+'" in Yandex, you have to remove it')

    def check_names_existance(self):
        cur = self.db.cur
        if len(self.names) != 0:
            for name in self.names:
                cur.execute("select yandex_id from yandex_objects.organization "
                            " where name_standardized = '"+name+"' limit 1")
                coincidence = cur.fetchall()
                if len(coincidence) == 0:
                    raise Exception('There is no such name_standardized "'+str(name)+'" in Yandex, you have to remove it')

    def get_elements(self):
        cur = self.db.cur
        cur.execute('select elements from metadata.rubrics_radii where rus = \'' + self.ru_category + '\'')
        elements = cur.fetchone()[0]
        return tuple(elements.split(';'))

    def get_names(self):
        cur = self.db.cur
        cur.execute('select names from metadata.rubrics_radii where rus = \'' + self.ru_category + '\'')
        names = cur.fetchone()[0]
        if len(names) != 0:
            return tuple(names.split(','))
        else:
            return False

    def get_eng_rubric_name_by_ru(self):
        cur = self.db.cur
        cur.execute('select eng from metadata.rubrics_radii where rus = \'' + self.ru_category + '\'')
        en_category = cur.fetchone()[0]
        return en_category

    def get_ru_rubric_name_by_eng(self):
        cur = self.db.cur
        cur.execute('select rus from metadata.rubrics_radii where eng = \'' + self.en_category + '\'')
        ru_category = cur.fetchone()[0]
        return ru_category

    def calculate_radii(self, parsing_date='last', data_query='auto', radii_count=30):
        cwd = os.getcwd()
        self.info_loger.write_to_log('function', 'calculate_radii')
        self.info_loger.write_to_log('category', self.en_category)
        self.info_loger.write_to_log('elements', str(self.elements))
        self.info_loger.write_to_log('names', str(self.names))
        self.info_loger.write_to_log('names_denial', self.names_denial)
        self.info_loger.write_to_log('elements_denial', self.elements_denial)
        os.chdir(get_build_location)
        if parsing_date == 'last':
            try:
                date = self.get_objects_assembly_date()
                if data_query == 'auto':
                    data_query = self.make_data_query(self.elements, self.names,
                                                      self.elements_denial, self.names_denial)
                
                check_call_string = self.make_check_call_string(data_query, self.en_category, radii_count)
                self.info_loger.write_to_log('date_objects_assembly', date)
                check_call([check_call_string], shell=True)
                self.info_loger.write_to_log('done', True)
                self.info_loger.push()
            except Exception as e:
                self.info_loger.write_to_log('error', str(e))
                self.info_loger.push()
        os.chdir(cwd)

    def sum_radii(self, radii_count=30, measurment_system='meter'):
        if measurment_system is 'meter':
            radii_counts_small = ['0', '100', '300', '500', '600']
            radii_counts_big = [str((x+1)*1000) for x in range(int(radii_count/10))]
            radii_counts = radii_counts_small + radii_counts_big
        elif measurment_system is 'imperial':
            radii_counts = ['0', '400', '800', '1600', '2400', '3200']
        self.info_loger.write_to_log('function', 'sum_radii')
        self.info_loger.write_to_log('category', self.category)
        cur = self.db.cur
        self.drop()
        self.info_loger.write_to_log('output_table', self.rubrikator_schema+'.'+self.en_category)
        self.info_loger.write_to_log('input_table', self.radii_schema+'.'+self.en_category)
        line = 'select city_id, square_id, _0 as radius_0 '
        try:
            for counter, radius in enumerate(radii_counts):
                if counter != 0:
                    list = ["cast(_" + str(x) + ' as integer)' for x in range(0, int(radius) + 100, 100)]
                    line += ',' + '+'.join(list) + ' as radius_' + str(radius)
            line += ' into "'+self.rubrikator_schema+'"."' + self.en_category +'"'
            line += ' from "'+self.radii_schema+'"."' + self.en_category + '" '
            cur.execute(line)
            self.db.commit()
            self.info_loger.push()
        except Exception as e:
            self.info_loger.write_to_log('error', str(e))
            self.info_loger.push()

    def check_recency(self, recalc=False, radii_count=30):
        date_calculated = self.get_objects_calculation_assembly_date()
        date_assembled = self.get_objects_assembly_date()
        print('objects was assembled on '+str(date_assembled))
        print(self.en_category+' was calculated on ' +str(date_calculated))
        if ((date_assembled != date_calculated) or recalc) & (self.en_category not in ('flats', 'stops17',
                                                                                       'actual_routes', 'all_objects',
                                                                                       'population','square_meter_price')):
            self.calculate_radii(radii_count=radii_count)
            self.sum_radii(radii_count)
            return 'Freshened'
        else:
            return 'Already Fresh'

    @staticmethod
    def change_col_names(df, name):
        old = list(df.columns)
        new = []
        for col in old:
            if 'radius' in col:
                new.append(col.replace('radius', name))
            else:
                new.append(col)
        df.columns = new
        return (df)

    def get_radii_df(self, df):
        t = Table('test_jazz.get_radii_temp', db=self.db)
        t.copy_df(df[['city_id', 'square_id']].dropna().drop_duplicates(), if_exists='replace')
        df = pd.read_sql("select * from test_jazz.get_radii('test_jazz', 'get_radii_temp', '%s')" % self.en_category,
                         self.db.engine)
        df = self.change_col_names(df.dropna(), self.en_category)
        t.drop()
        return df


def main():
    #for cat in ["Интернет-магазин","Бытовые услуги","Кафе","Пункт выдачи","Денежные переводы","Юридические услуги","Платежный терминал","Банкомат","Магазин продуктов","Автомобильная парковка","Ресторан","Парикмахерская","Шиномонтаж","Автостоянка","Магазин одежды","Дополнительное образование","Строительная компания","Салон красоты","Автосервис, автотехцентр","Магазин автозапчастей и автотоваров"]:
    cat = "Интернет-магазин"
    radii = Radii(cat)
    radii.check_recency()
    # radii.calculate_radii()
    # radii.sum_radii()


if __name__ == '__main__':
    main()
