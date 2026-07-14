G identity<G> (G a) {
	return a;
}

int main () {
	if (identity<int> (42) != 42) return 1;
	if (identity<string> ("hello") != "hello") return 2;
	if (identity<int> (-7) != -7) return 3;
	return 0;
}
