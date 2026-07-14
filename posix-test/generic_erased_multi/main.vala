A first<A,B> (A a, B b) { return a; }
B second<A,B> (A a, B b) { return b; }

int main () {
	if (first<int,string> (7, "x") != 7) return 1;
	if (second<int,string> (7, "hi") != "hi") return 2;
	if (first<string,int> ("k", 3) != "k") return 3;
	if (second<string,int> ("k", 9) != 9) return 4;
	return 0;
}
