[Flags]
enum Perm {
	READ,
	WRITE,
	EXEC
}

void main() {
	Perm p = Perm.READ | Perm.WRITE;
	assert((p & Perm.READ) != 0);
	assert((p & Perm.WRITE) != 0);
	assert((p & Perm.EXEC) == 0);
	assert(Perm.READ in p);
	assert(!(Perm.EXEC in p));
	p |= Perm.EXEC;
	assert(Perm.EXEC in p);
	p &= ~Perm.READ;
	assert(!(Perm.READ in p));
}
