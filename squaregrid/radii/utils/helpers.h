#include <map>
#include <vector>

namespace utils {

template<typename DataType> struct AddableVector {
	public:
		AddableVector<DataType>& operator += (
				const AddableVector<DataType> &v) {
			data.insert(data.end(), v.data.begin(), v.data.end());
			return *this;
		}

		AddableVector<DataType> operator + (
				const AddableVector<DataType> &v) {
			AddableVector<DataType> result = *this;
			result += v;
			return result;
		}

		std::vector<DataType> data;
};

template<typename DataType> struct Averager {
	public:
		Averager(): sum(), count(0) {}

		Averager(DataType value) {
			sum = value;
			count = 1;
		}

		Averager<DataType>& operator += (
				const Averager<DataType> &v) {
			sum = sum + v.sum;
			count += v.count;
			return *this;
		}

		Averager<DataType> operator + (
				const Averager<DataType> &v) {
			Averager<DataType> result = *this;
			result += v;
			return result;
		}

		auto value() const {
			return sum / count;
		}

		bool operator == (const Averager<DataType> &a) const {
			return value() == a.value();
		}

		operator float_t() const {
			return (float_t) (sum / count);
		}

		operator int() const {
			return (int) (sum / count);
		}

		DataType sum;
		int count;
};

template<typename DataType> struct OccurrenceCounter {
	public:
		OccurrenceCounter<DataType>& operator += (
				const OccurrenceCounter<DataType> &v) {
			for (const auto it : v.data) {
				data[it.first] += it.second;
			}
			return *this;
		}

		OccurrenceCounter<DataType>& operator + (
				const OccurrenceCounter<DataType> &v) {
			OccurrenceCounter<DataType> result = *this;
			result += v;
			return result;
		}

		std::map<DataType, int> data;
};

}  // namespace utils
