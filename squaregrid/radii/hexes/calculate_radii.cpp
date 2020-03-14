#include <bits/stdc++.h>
#include <json/json.h>

using namespace std;

typedef float lf;
typedef vector<int> vi;
typedef vector<lf> pt;

const int N = 71499;
const lf phi = (1 + sqrt(5.0)) / 2.0;

vector<pt> poly;
vector<vi> faces;
vector<vi> adj_faces;

lf dist(const pt &a, const pt &b) {
	assert(a.size() == b.size());
	lf res = 0;
	for (int i = 0; i < (int) a.size(); ++i) {
		res = hypot(res, a[i] - b[i]);
	}
	return res;
}

pt operator + (const pt &a, const pt &b) {
	assert(a.size() == b.size());
	pt res(a.size());
	for (int i = 0; i < (int) a.size(); ++i) {
		res[i] = a[i] + b[i];
	}
	return res;
}

pt operator * (const pt &a, const lf k) {
	pt res(a.size());
	for (int i = 0; i < (int) a.size(); ++i) {
		res[i] = a[i] * k;
	}
	return res;
}

void gen_poly() {
	lf h = 1.15;

	for (int m = 0; m < 8; ++m) {
		poly.emplace_back(3);
		for (int i = 0; i < 3; ++i) {
			poly.back()[i] = 1 - 2 * ((m >> i) & 1);
		}
	}
	for (int s1: {-1, 1}) {
		for (int s2: {-1, 1}) {
			poly.emplace_back(vector<lf>{0., s1 / phi, s2 * phi});
			poly.emplace_back(vector<lf>{s1 / phi, s2 * phi, 0.});
			poly.emplace_back(vector<lf>{s2 * phi, 0., s1 / phi});
		}
	}

	vector<pt> new_v;
	int cnt = poly.size();
	for (int s1: {-1, 1}) {
		for (int s2: {-1, 1}) {
			for (const vi &perm: {vi{0, 1}, vi{1, 2}, vi{2, 0}}) {
				vi face;
				pt O(3);
				for (int i = 0; i < (int) poly.size(); ++i) {
					if (fabs(phi * poly[i][perm[0]] + s1 * poly[i][perm[1]] -
								s2 * phi * phi) < 1e-5) {
						face.push_back(i);
						O = O + poly[i];
					}
				}
				assert(face.size() == 5);
				for (int i = 0; i < 4; ++i) {
					for (int j = i + 1; j < 5; ++j) {
						if (fabs(dist(poly[face[i]], poly[face[j]])) < 1e-5) {
							swap(face[i + 1], face[j]);
						}
					}
				}
				face.push_back(face[0]);
				O = O * h;
				new_v.push_back(O);
				for (int i = 0; i < 5; ++i) {
					faces.push_back({cnt, face[i], face[i + 1]});
				}
				cnt++;
			}
		}
	}
	poly.insert(poly.end(), new_v.begin(), new_v.end());
	assert(faces.size() == 60);
	assert(poly.size() == 32);

	adj_faces.assign(poly.size(), vi(poly.size()));
	for (int i = 0; i < (int) faces.size(); ++i) {
		for (int j = 0; j < 3; ++j) {
			adj_faces[faces[i][j]][faces[i][(j + 1) % 3]] ^= i;
			adj_faces[faces[i][(j + 1) % 3]][faces[i][j]] ^= i;
		}
	}
}

vi get_vertex_hex(int v) {
	for (int i = 0; i < (int) faces.size(); ++i) {
		for (int j = 0; j < 3; ++j) {
			if (faces[i][j] == v) {
				vi hex_id(4);
				hex_id[0] = i;
				hex_id[j + 1] = N;
				return hex_id;
			}
		}
	}
	assert(false);
}

vi unify_hex_id(const vi &hex_id) {
	int f_id = hex_id[0];
	vi bari(hex_id.begin() + 1, hex_id.end());
	int nz = 0;
	for (int i = 0; i < 3; ++i) {
		if (bari[i] != 0) nz++;
	}
	for (int pos = 0; pos < 3; ++pos) {
		if (bari[pos] > 0) continue;

		int v1 = faces[f_id][(pos + 1) % 3];
		int v2 = faces[f_id][(pos + 2) % 3];

		int new_face_id = adj_faces[v1][v2] ^ f_id;
		const vi &new_face = faces[new_face_id];
		int i1 = find(new_face.begin(), new_face.end(), v1) - new_face.begin();
		int i2 = find(new_face.begin(), new_face.end(), v2) - new_face.begin();
		int i3 = 3 - i1 - i2;

		vi new_bari = bari;

		if (bari[pos] == 0) {
			if (nz == 1) {
				for (int j = 0; j < 3; ++j) {
					if (bari[j] != 0) {
						return get_vertex_hex(faces[f_id][j]);
					}
				}
				assert(false);
			}

			int min_face_id = f_id;

			if (new_face_id < min_face_id) {
				new_bari.assign(3, 0);
				new_bari[i1] = bari[(pos + 1) % 3];
				new_bari[i2] = bari[(pos + 2) % 3];
				min_face_id = new_face_id;
			}
			new_bari.insert(new_bari.begin(), min_face_id);
			return new_bari;
		}
		new_bari.assign(3, 0);
		new_bari[i1] = bari[(pos + 1) % 3] + bari[pos];
		new_bari[i2] = bari[(pos + 2) % 3] + bari[pos];
		new_bari[i3] = -bari[pos];
		new_bari.insert(new_bari.begin(), new_face_id);
		return unify_hex_id(new_bari);
	}
	return hex_id;
}

vector<vi> hex_neighbors(const vi &hex_id) {
	int f_id = hex_id[0];
	vi bari(hex_id.begin() + 1, hex_id.end());
	vector<vi> res;
	int nz = 0, v = -1;
	for (int i = 0; i < 3; ++i) {
		if (bari[i] != 0) nz++, v = i;
	}
	if (nz == 1) {
		for (int i = 0; i < (int) faces.size(); ++i) {
			for (int j = 0; j < 3; ++j) {
				if (faces[i][j] == v) {
					vi new_bari(3, 0);
					new_bari[j] = N - 2;
					new_bari[(j + 1) % 3] = 1;
					new_bari[(j + 2) % 3] = 1;
					new_bari.insert(new_bari.begin(), i);
					res.push_back(new_bari);
				}
			}
		}
		return res;
	}
	for (const vi &delta: {
			vi{-1, 2, -1}, vi{-2, 1, 1}, vi{-1, -1, 2},
			vi{1, -2, 1}, vi{2, -1, -1}, vi{1, 1, -2}}) {
		vi new_bari = bari;
		for (int i = 0; i < 3; ++i) {
			new_bari[i] += delta[i];
		}
		new_bari.insert(new_bari.begin(), f_id);
		res.push_back(unify_hex_id(new_bari));
	}
	assert(res.size() == 6);
	assert(set<vi>(res.begin(), res.end()).size() == 6);
	return res;
}

vector<int> bfs(const vi &hex_id, const map<vi, int> &hex_value, int max_dist) {
	vector<int> res(max_dist + 1);
	map<vi, int> dist;
	queue<vi> q;
	dist[hex_id] = 0;
	q.push(hex_id);
	while (!q.empty()) {
		auto cur_hex = q.front();
		q.pop();
		if (hex_value.count(cur_hex)) {
			res[dist[cur_hex]] += hex_value.at(cur_hex);
		}
		if (dist[cur_hex] >= max_dist) continue;

		for (const vi& n: hex_neighbors(cur_hex)) {
			if (dist.count(n)) {
				continue;
			}
			dist[n] = dist[cur_hex] + 1;
			q.push(n);
		}
	}
	return res;
}

int main() {
	gen_poly();

	vi hid{1, N - 2, 1, 1};
	for (const vi &n: hex_neighbors(hid)) {
		for (int j = 0; j < (int) n.size(); ++j) {
			cerr << n[j] << " ";
		}
		cerr << endl;
	}

	Json::Value root;
	ifstream inf("hexes.json");
	inf >> root;
	vector<vi> hex_ids;
	map<vi, int> hex_value;
	for (const auto &id: root["hex_id"]) {
		hex_ids.emplace_back();
		for (const auto &id_component: id) {
			hex_ids.back().push_back(id_component.asInt());
		}
	}

	int cnt = 0;
	for (const auto &count: root["count"]) {
		hex_value[hex_ids[cnt++]] = count.asInt();
	}
	cout << hex_value.size() << " hexes" << endl;

	Json::Value dists;
	cnt = 0;
	for (const auto &hex_id : hex_ids) {
		auto d = bfs(hex_id, hex_value, 50);
		for (int i = 1; i <= 50; ++i) d[i] += d[i - 1];
		Json::Value cur;
		for (int x : d) cur.append(x);

		dists[to_string(cnt)] = cur;
		cnt++;
		cerr << cnt << endl;
	}
	root["in_radius"] = dists;

	ofstream ouf("hexes_with_rad.json");
	ouf << root << endl;
}
