class Foo : Object {
    public string name;
    
    public Foo (string name) {
        this.name = name;
    }
}

Foo? helper5 () {
    var f = new Foo ("Object 5");
    weakref Foo? w = f;
    
    return w;
}

void main () {
    var obj = helper5 ();
    assert (obj != null);
    assert (obj.name == "Object 5");
}
