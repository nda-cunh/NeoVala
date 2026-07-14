public class Thing {
	public int v;
}

[CCode (has_target = false)]
public delegate bool CompareFunc<G> (G a, G b);

bool int_compare (int a, int b) {
	return a == b;
}

public CompareFunc<G>? from_type<G> () {
	if (typeof (G) == typeof (int)) {
		return (int_compare);
	}
	return null;
}

public string type_name<G> () {
	return typeof (G).name;
}
