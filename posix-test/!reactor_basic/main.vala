using Posix;

int ticks = 0;
bool fd_fired = false;
unowned Reactor loop;
int[] fds;

void check (bool cond) {
	if (!cond)
		Posix.exit (1);
}

void main () {
	loop = Reactor.default ();

	fds = new int[2];
	pipe (fds);
	Posix.write (fds[1], "x", 1);

	loop.add_fd (fds[0], POLLIN, () => {
		char buf[8];
		Posix.read (fds[0], buf, 1);
		fd_fired = true;
		loop.del_fd (fds[0]);
	});

	loop.add_timer (5, true, () => {
		ticks++;
		if (ticks >= 3)
			loop.stop ();
	});

	loop.run ();

	Posix.close (fds[0]);
	Posix.close (fds[1]);

	check (fd_fired);
	check (ticks == 3);
}
