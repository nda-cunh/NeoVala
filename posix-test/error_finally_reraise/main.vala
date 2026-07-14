errordomain MyError { BAD }

int trace = 0;

void may_fail (int n) throws MyError {
	if (n < 0)
		throw new MyError.BAD ("bad");
}

void wrapper (int n) throws MyError {
	try {
		may_fail (n);
		trace += 10;
	} finally {
		trace += 1;
	}
}

void main() {
	try {
		wrapper (-1);
		assert (false);
	} catch (MyError e) {
		assert (e.message == "bad");
	}
	assert (trace == 1);

	try {
		wrapper (5);
	} catch (MyError e) {
		assert (false);
	}
	assert (trace == 12);
}
