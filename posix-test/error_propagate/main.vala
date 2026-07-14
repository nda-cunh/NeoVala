errordomain MathError {
	DIV_BY_ZERO,
	NEGATIVE
}

class Calculator {
	public int divide (int a, int b) throws MathError {
		if (b == 0)
			throw new MathError.DIV_BY_ZERO ("division by zero");
		return a / b;
	}
}

int run () {
	var c = new Calculator ();
	int total = 0;

	try {
		total += c.divide (10, 2);
		assert (total == 5);
		total += c.divide (1, 0);
		assert (false);
	} catch (MathError e) {
		assert (e.message == "division by zero");
		assert (e is MathError.DIV_BY_ZERO);
	}

	return total;
}

void main () {
	int t = run ();
	assert (t == 5);
}
