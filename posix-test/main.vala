//valac main.vala --pkg=gio-2.0

class Worker {

    public static void run_test (void* data) {
        string dir_name = (string) data;

		const string path_project = "/home/nda-cunh/Desktop/NeoVala";

		try {
			string valac = "%s/usr/bin/valac --profile=posix --vapidir=%s/usr/share/vala-0.58/vapi/"
				.printf(path_project, path_project);

			string[] envp = Environ.get ();
			envp = Environ.set_variable (envp, "VALAC", valac, true);

			// Force the child valac to resolve its libs from ./usr, not ~/.local.
			// LD_LIBRARY_PATH wins over the binary's RUNPATH, so the shell's
			// ~/.local entry would otherwise shadow the freshly installed usr libs.
			string ld_path = "%s/usr/lib:%s/usr/lib/vala-0.58"
				.printf (path_project, path_project);
			envp = Environ.set_variable (envp, "LD_LIBRARY_PATH", ld_path, true);

			string basename = Path.get_basename (dir_name);

			if (basename[0] == '!') {
				stderr.printf ("\033[33m[TESTER SKIP] %s\033[0m\n", basename);
				return;
			}

			string[] argv = {
				"make",
				"--no-print-directory",
				"run",
				"-C",
				dir_name,
				null
			};


            int status;
			string output;
			string errput;

            Process.spawn_sync (
                null,
                argv,
                envp,
                SpawnFlags.SEARCH_PATH,
                null,
                out output,
                out errput,
                out status
            );

			if (basename[0] == '@') {
				if (status == 0)
					print ("\033[31m[KO] %s %s\033[0m\n", errput, basename);
				else
					print ("\033[32m[Ok (dont compile)] %s\033[0m\n", basename);
			}
			else {
				if (status == 0) {
					print ("\033[32m[OK] %s\033[0m\n", basename);
				} else {
					print ("\033[31m[KO] %s %s\033[0m\n", errput, basename);
				}
			}
        }
        catch (Error e) {
            stderr.printf ("\033[31m[TESTER SPAWN KO] %s (%s)\033[0m\n", dir_name, e.message);
        }
    }
}


void run_tests (string []lst_dirs) throws Error {
	var pool = new ThreadPool<void*>.with_owned_data (
		Worker.run_test,
		(int)get_num_processors (),
		false
	);

	foreach (string full_dir in lst_dirs) {
		try {
			pool.add ((owned) full_dir);
		}
		catch (Error e) {
			stderr.printf ("\033[31m[TESTER KO] %s (%s)\033[0m\n", full_dir, e.message);
		}
	}
}

void main (string []args) {
	try {
		// listed in the command line
		if (args.length > 1) {
			run_tests (args[1:]);
			return;
		}
		// all directories in the posix-test folder
		string path_project = "/home/nda-cunh/Desktop/NeoVala";
		Dir dir = Dir.open (path_project + "/posix-test");

		unowned string? name;
		string []lst_dirs = {};
		while ((name = dir.read_name ()) != null) {

			if (name == "." || name == "..")
				continue;

			string full_dir = Path.build_filename (path_project, "posix-test", name);

			if (FileUtils.test (full_dir, FileTest.IS_DIR) == false)
				continue;
			lst_dirs += full_dir;
		}
		run_tests (lst_dirs);
	}
	catch (Error e) {
		stderr.printf ("\033[31m[TESTER KO] %s\033[0m\n", e.message);
	}
}
