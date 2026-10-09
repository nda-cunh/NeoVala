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
    var f = new Foo ("Object 4");
    weakref Foo? w = f;
    
    assert (w != null);
    
    w = null;
	assert (count == 0);
    assert (w == null);
    
    assert (f.name == "Object 4");
}
