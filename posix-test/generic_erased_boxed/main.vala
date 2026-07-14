G id<G> (G a) { return a; }

int main () {
	double? d = id<double?> (3.5);
	if ((double) d != 3.5) return 1;
	int? n = id<int?> (12);
	if ((int) n != 12) return 2;
	bool? b = id<bool?> (true);
	if ((bool) b != true) return 3;
	return 0;
}
