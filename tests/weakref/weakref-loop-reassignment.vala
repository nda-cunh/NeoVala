class Foo : Object {
    public int id;

    public Foo (int id) {
        this.id = id;
    }
}

void main () {
    weakref Foo? w = null;

    for (int i = 0; i < 5; i++) {
        var f = new Foo (i);
        w = f;
        assert (w != null);
        assert (w.id == i);
    }

    assert (w == null);
}
