int count = 0;

class Foo : Object {
    public string name;

    public Foo (string name) {
        this.name = name;
    }
	~Foo() {
		count++;
	}
}

class Holder : Object {
    public weakref Foo? target;
}

void main () {
    var holder = new Holder ();

    {
        var f = new Foo ("Objet Field 2");
        holder.target = f;
        assert (holder.target != null);
    }

    assert (holder.target == null);
	assert (count == 1);
}
