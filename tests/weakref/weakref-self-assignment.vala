class Foo : Object {
    public string name;
    
    public Foo (string name) {
        this.name = name;
    }
}

void main () {
    var f = new Foo ("Object 6");
    weakref Foo? w = f;
    
    w = w;
    
    assert (w == f);
}
