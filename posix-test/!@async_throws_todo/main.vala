public errordomain E { OOPS }

async int risky (int x) throws E {
	if (x < 0)
		throw new E.OOPS ("neg");
	return x;
}

void main () {
	risky.begin (1, (s, r) => {});
}
