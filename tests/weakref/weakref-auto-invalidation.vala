int count = 0;

class Foo : Object {
    public string name;
    
    public Foo (string name) {
        this.name = name;
    }
	~Foo () {
		count++;
	}
}

void main () {
    weakref Foo? w = null;
    
    {
        var f = new Foo ("Object 1");
        w = f;
        assert (w != null);
        assert (w.name == "Object 1");
		assert (count == 0);
    }
    
    assert (w == null);
	assert (count == 1);
}
