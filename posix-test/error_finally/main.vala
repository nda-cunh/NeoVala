errordomain MyError { BAD }

void may_fail (int n) throws MyError {
	if (n < 0)
		throw new MyError.BAD ("bad");
}

void main() {
	int cleanup = 0;
	try {
		may_fail (-1);
		assert (false);
	} catch (MyError e) {
		assert (e.message == "bad");
	} finally {
		cleanup++;
	}
	assert (cleanup == 1);

	try {
		may_fail (1);
	} catch (MyError e) {
		assert (false);
	} finally {
		cleanup++;
	}
	assert (cleanup == 2);
}
