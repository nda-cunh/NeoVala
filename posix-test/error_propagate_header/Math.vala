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

