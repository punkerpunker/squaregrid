#pragma once

#include <vector>

#include "grids/grid_metadata.h"

namespace processing {
	template<typename DataType> class DataGrid {
		public:
			DataGrid(const grids::GridMetadata &metadata) {
				data_.assign(
						metadata.GetSide() * 2,
						std::vector<DataType>(metadata.GetSide() * 2));
			}

			DataGrid(const DataGrid<DataType> &g): data_(g.data_) {}
			DataGrid(int side): data_(side, std::vector<DataType>(side)) {}
			DataGrid(int n, int m): data_(n, std::vector<DataType>(m)) {}
			DataGrid(): data_() {}

			std::vector<DataType>& operator [] (int row_idx) {
				return data_[row_idx];
			}

			const std::vector<DataType>& operator [] (int row_idx) const {
				return data_[row_idx];
			}

			std::vector< std::vector<DataType> >& data() {
				return data_;
			}

			const std::vector< std::vector<DataType> >& data() const {
				return data_;
			}

			int NumRows() const {
				return data_.size();
			}

			int NumCols() const {
				if (data_.empty()) return 0;
				return data_[0].size();
			}
		private:
			std::vector< std::vector<DataType> > data_;
	};
}
