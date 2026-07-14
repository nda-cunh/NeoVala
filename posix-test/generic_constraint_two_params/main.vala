interface A { public abstract int a (); }
interface B { public abstract int b (); }
class Ca : A { public int a () { return 10; } }
class Cb : B { public int b () { return 20; } }
int combine<X : A, Y : B> (X x, Y y) { return x.a () + y.b (); }
int main () {
	if (combine<Ca, Cb> (new Ca (), new Cb ()) != 30) return 1;
	return 0;
}
