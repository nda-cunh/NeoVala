void main () {
	uint8 buffer[4];
	((char*) buffer)[0] = (char) 65;
	((char*) buffer)[1] = (char) 66;
	assert (buffer[0] == 'A');
	assert (buffer[1] == 'B');
}
