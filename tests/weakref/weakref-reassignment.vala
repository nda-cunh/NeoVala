class Foo : Object {
    public string name;
    
    public Foo (string name) {
        this.name = name;
    }
}

void main () {
    weakref Foo? w = null;
    var f1 = new Foo ("Object A");
    
    {
        var f2 = new Foo ("Object B");
        
        w = f1;
        assert (w == f1);
        
        w = f2;
        assert (w == f2);
        
    }
    
    assert (w == null);
    f1 = null; 
}
