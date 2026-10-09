class Foo : Object {
    public string name;

    public Foo (string name) {
        this.name = name;
    }
}

class Holder : Object {
    public weakref Foo? target;
}

void main () {
    var holder = new Holder ();
    var f1 = new Foo ("Object A");

    {
        var f2 = new Foo ("Object B");

        holder.target = f1;
        assert (holder.target == f1);

        holder.target = f2;
        assert (holder.target == f2);
    }

    assert (holder.target == null);
    assert (f1 != null);
}
