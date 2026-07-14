interface Killable {
	public abstract void kill ();
}

abstract class Personnage : Killable {
	protected Personnage () {
	}

	public virtual void kill () {
		print ("base kill\n");
		assert (false);
	}
}

class Luigi : Personnage {
	public Luigi () {
		base ();
	}

	public override void kill () {
		print ("Luigi killed\n");
	}
}

void main () {
	var luigi = new Luigi ();
	luigi.kill ();

	unowned Personnage p = luigi;
	p.kill ();

	unowned Killable k = luigi;
	k.kill ();
}
