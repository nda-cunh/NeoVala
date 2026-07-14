public class Parent {
	public int id;
	public Parent (int id) { this.id = id; }
}

public class Child {
	public weakref Parent? parent;
	public Child () { this.parent = null; }
}

public class Base { public int v; public Base (int v) { this.v = v; } }
public class Derived : Base { public Derived (int v) { base (v); } }

void main () {
	// local weakref: target dies while the reference is alive -> auto-null
	weakref Parent? w = null;
	assert (w == null);
	{
		var p = new Parent (42);
		w = p;
		assert (w != null);
		if (w != null) assert (w.id == 42);
	}
	assert (w == null);

	// weakref field (parent pointer): parent dies first
	var c = new Child ();
	{
		var p = new Parent (7);
		c.parent = p;
		if (c.parent != null) assert (c.parent.id == 7);
	}
	assert (c.parent == null);

	// weakref field holder dies first -> no dangling slot on the target
	var survivor = new Parent (9);
	{
		var c2 = new Child ();
		c2.parent = survivor;
		if (c2.parent != null) assert (c2.parent.id == 9);
	}
	assert (survivor.id == 9);

	// reassign between two live targets: the old target must unregister
	var a = new Base (1);
	var b = new Base (2);
	weakref Base? r = a;
	r = b;
	if (r != null) assert (r.v == 2);

	// polymorphism: a Derived stored through a Base weakref still auto-nulls
	weakref Base? d = null;
	{
		var der = new Derived (5);
		d = der;
		if (d != null) assert (d.v == 5);
	}
	assert (d == null);

	// `weakref var`: inferred type keeps the weak reference semantics
	{
		var owner = new Parent (11);
		weakref var wv = owner;
		assert (wv != null);
		if (wv != null) assert (wv.id == 11);
	}

	print ("weakref OK\n");
}
