class NotAnIface {
	public int v;
}
int f<G : NotAnIface> (G a) {
	return 0;
}
int main () {
	return 0;
}
