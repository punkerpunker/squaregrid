from libcpp.vector cimport vector
from libcpp.utility cimport pair

from grids.pywrap_grid_metadata cimport EnumerateGridCells
from processing.pywrap_data_grid cimport DataGrid
from processing.pywrap_radii_summation cimport CalculateRadii

import argparse
import logging
import pandas

def main():
	logging.basicConfig(
			level=logging.DEBUG,
			format='%(asctime)s %(thread)s %(threadName)s %(levelname)s: %(message)s')
	parser = argparse.ArgumentParser(
			description='Output number of cells in radius',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)

	parser.add_argument('--grid_half_size', type=int, required=True,
			help='Half of grid size')
	parser.add_argument('--radii', type=str, required=True,
			help='Comma separated list of radii to fetch')
	parser.add_argument('--output_file', type=str, required=True,
			help='Output CSV file')
	args = parser.parse_args()

	args.radii = list(map(int, args.radii.split(',')))
	for r in args.radii:
		if r % 100 != 0:
			logging.error('All radii must be multiple of 100')
			return

	cdef int n = 2 * args.grid_half_size, max_R = max(args.radii) // 100, i, j
	cdef DataGrid[int] grid = DataGrid[int](n)
	cdef vector[DataGrid[int]] radii
	cdef vector[pair[int,int]] cells = EnumerateGridCells(args.grid_half_size)

	for i in range(n):
		for j in range(n):
			grid[i][j] = 1

	CalculateRadii[int](grid, max_R + 1, &radii, True)
	df = pandas.DataFrame({'square_id': range(n * n)})
	for r in args.radii:
		df['locality_' + str(r)] = df['square_id'].apply(
				lambda x: radii[r // 100][cells[x].first][cells[x].second])
	df.to_csv(args.output_file, index=False)
	print(df.head())


if __name__ == '__main__':
	main()
