interface Alive {
	public virtual void breathe() {
		print("I am breathing\n");
	}
}

abstract class Person {
	public abstract void speak();
}

class Mario : Person, Alive {
	public override void speak() {
		print("It's-a me, Mario!\n");
	}
}

class Luigi : Person, Alive {
	public override void speak() {
		print("It's-a me, Luigi!\n");
	}

	public override void breathe() {
		print("I am breathing, but I am Luigi!\n");
	}
}

void main() {
	var mario = new Mario();
	mario.speak();
	mario.breathe();
	var luigi = new Luigi();
	luigi.speak();
	luigi.breathe();
}
