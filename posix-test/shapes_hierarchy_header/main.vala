void main () {
	Shape r = new Rectangle (3, 4);
	Shape s = new Square (5);
	assert (r.area () == 12.0);
	assert (s.area () == 25.0);
	print ("%s\n%s\n", r.describe (), s.describe ());
}
