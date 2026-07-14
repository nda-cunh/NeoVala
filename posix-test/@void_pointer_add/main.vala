void main () {
	int a = 42;
	void *p = &a;
	size_t z = (size_t)(p * 2);
	print ("%zu\n", z);
}
