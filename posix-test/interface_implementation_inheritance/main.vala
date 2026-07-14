interface Killable {
	public abstract void kill();
}

class Personnage : Killable {
	public void kill() {
		print("Personnage killed");
	}

}


class Mario : Personnage {

}

void main() {
	var mario = new Mario();
	mario.kill();
}
