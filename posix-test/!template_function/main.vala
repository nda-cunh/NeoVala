template T max<T> (T a, T b) {
	return a > b ? a : b;
}

void main () {
	int i = max<int> (3, 9);
	print ("%d\n", i);
	double d = max<double> (2.5, 1.5);
	print ("%g\n", d);
}
