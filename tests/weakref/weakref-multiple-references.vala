class Foo : Object {
    public string name;
    
    public Foo (string name) {
        this.name = name;
    }
}

void main () {
    weakref Foo? w1 = null;
    weakref Foo? w2 = null;
    
    {
        var f = new Foo ("Shared Object");
        w1 = f;
        w2 = f;
        
        assert (w1 == f);
        assert (w2 == f);
    }
    
    assert (w1 == null);
    assert (w2 == null);
}
