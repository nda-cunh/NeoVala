void main () {
	// mixed positional / designated: positional resumes after last index
	int[] mix = { 10, [4] = 50, 60, 70 };
	assert (mix.length == 7);
	assert (mix[0] == 10);
	assert (mix[1] == 0);
	assert (mix[4] == 50);
	assert (mix[5] == 60);
	assert (mix[6] == 70);
}
