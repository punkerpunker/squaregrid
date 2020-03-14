import pandas
import numpy

from utils.datamart_pb2 import DataMart

def create_datamart_from_df(df) -> DataMart:
	result = DataMart()
	result.nrows = len(df)
	for col in df.columns:
		column = result.columns.add()
		column.name = col
		for val in df[col]:
			cell = column.cells.add()
			if df[col].dtype == numpy.int32 or df[col].dtype == numpy.int64:
				cell.int_val = val
			elif df[col].dtype == numpy.float32 or df[col].dtype == numpy.float64:
				cell.float_val = val
			else:
				cell.str_val = str(val)
	return result


def create_df_from_datamart(mart) -> pandas.DataFrame:
	if mart.nrows == 0:
		return pandas.DataFrame()
	dct = dict()
	for col in mart.columns:
		col_name = col.name
		if len(col.cells) > 0:
			dtype = col.cells[0].WhichOneof("data_type")
			if dtype == 'int_val':
				dct[col.name] = [x.int_val for x in col.cells]
			elif dtype == 'float_val':
				dct[col.name] = [x.float_val for x in col.cells]
			else:
				dct[col.name] = [x.str_val for x in col.cells]
		else:
			dct[col.name] = list()
	return pandas.DataFrame(dct)
