void describe (IShape s) {
	print ("%s area=%.2f\n", s.name (), s.area ());
}

void main () {
	IShape a = new Circle (2.0);
	IShape b = new Square (3.0);
	describe (a);
	describe (b);
}
