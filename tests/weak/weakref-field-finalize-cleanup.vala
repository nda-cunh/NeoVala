class Foo : Object {
    public string name;

    public Foo (string name) {
        this.name = name;
    }
}

class Holder : Object {
    public weak Foo? target;
}

void main () {
    var f = new Foo ("Object Field 3");

    {
        var holder = new Holder ();
        holder.target = f;
        assert (holder.target == f);
    }

    f = null;
}
