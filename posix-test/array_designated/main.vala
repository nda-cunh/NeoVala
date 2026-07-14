void main () {
	int[] tab = { [1] = 41, [3] = 12, [15] = 24 };
	assert (tab.length == 16);
	assert (tab[0] == 0);
	assert (tab[1] == 41);
	assert (tab[2] == 0);
	assert (tab[3] == 12);
	assert (tab[15] == 24);
	print ("ok\n");
}
