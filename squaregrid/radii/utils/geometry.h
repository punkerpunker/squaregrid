#pragma once

#include "utils/common.h"

namespace utils {
	template<typename FloatType> struct Vector2D {
		FloatType x, y;

		Vector2D(FloatType x = 0, FloatType y = 0): x(x), y(y) {}

		Vector2D operator - (const Vector2D &v) const {
			return Vector2D(x - v.x, y - v.y);
		}

		Vector2D operator + (const Vector2D &v) const {
			return Vector2D(x + v.x, y + v.y);
		}

		Vector2D operator * (const FloatType k) const {
			return Vector2D(x * k, y * k);
		}

		Vector2D operator / (const FloatType k) const {
			return Vector2D(x / k, y / k);
		}

		FloatType DotProduct(const Vector2D &v) const {
			return x * v.x + y * v.y;
		}

		FloatType CrossProduct(const Vector2D &v) const {
			return x * v.y - y * v.x;
		}

		FloatType Norm() const {
			return hypotl(x, y);
		}

		FloatType NormSquared() const {
			return this->DotProduct(*this);
		}

		Vector2D Normalized() const {
			return *this / this->Norm();
		}
	};

	template<typename FloatType> using Point2D = Vector2D<FloatType>;
}
