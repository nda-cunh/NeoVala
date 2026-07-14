int main () {
	// cross-TU typeof identity: the descriptor for `int` lives in a per-TU
	// static, so from_type<int> (defined in lib.vala) must still match.
	var f = from_type<int> ();
	if (f == null) return 1;
	if (!f (2, 2)) return 2;
	if (f (2, 3)) return 3;

	var g = from_type<Thing> ();
	if (g != null) return 4;

	// typeof(G).name across TU (generic param) and on a supraklass...
	if (type_name<int> () != "int") return 5;
	if (type_name<Thing> () != "Thing") return 6;
	// ...and same-TU, directly on a concrete typeof.
	if (typeof (int).name != "int") return 7;
	if (typeof (Thing).name != "Thing") return 8;
	return 0;
}
