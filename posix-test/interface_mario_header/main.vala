interface Alive {
	public virtual void breathe() {
		print("I am breathing\n");
	}
}

abstract class Person {
	public abstract void speak();
}

int NBR_M = 22;
class Mario : Person, Alive {
	public override void speak() {
		print("It's-a me, Mario!\n");
		NBR_M += 10;
	}
}

int NBR_L = 42;
class Luigi : Person, Alive {
	public override void speak() {
		print("It's-a me, Luigi!\n");
	}

	public override void breathe() {
		print("I am breathing, but I am Luigi!\n");
		NBR_L += 10;
	}
}

void main() {
	var mario = new Mario();
	mario.speak();
	mario.breathe();
	var luigi = new Luigi();
	luigi.speak();
	luigi.breathe();
	assert(NBR_M == 32);
	assert(NBR_L == 52);
}
