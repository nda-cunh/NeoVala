valac_sources = files(
	'valacompiler.vala',
)

valac_name = 'valac@0@'.format(vala_version_suffix)

rpath_prefix = '$ORIGIN'
if host_machine.system() == 'darwin'
	rpath_prefix = '@loader_path'
endif

valac_exe = executable(
	valac_name,
	valac_sources,
	install_rpath: rpath_prefix + '/../lib/vala' + vala_version_suffix,
	dependencies: [glib_dep, valacodegen_dep],
	install: true,
)

vala_name = 'vala@0@'.format(vala_version_suffix)

# https://github.com/mesonbuild/meson/issues/1602
meson.add_install_script('sh', '-c', 'cd $DESTDIR@0@; ln -fs --relative @1@ valac'.format(join_paths(get_option('prefix'), get_option('bindir')), valac_name))
meson.add_install_script('sh', '-c', 'cd $DESTDIR@0@; ln -fs --relative @1@ @2@'.format(join_paths(get_option('prefix'), get_option('bindir')), valac_name, vala_name))
meson.add_install_script('sh', '-c', 'cd $DESTDIR@0@; ln -fs --relative @1@ vala'.format(join_paths(get_option('prefix'), get_option('bindir')), valac_name))
