void main () {
	int a = 42;
	void *origin = &a;
	void *p = origin;
	p += 8;
	p = p - 4;
	long off = (long)(p - origin);
	print ("%ld\n", off);
}
