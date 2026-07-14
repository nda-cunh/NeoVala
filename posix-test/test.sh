#!/bin/sh
### OLD 

# PATH_PROJECT='/home/nda-cunh/Desktop/NeoVala'
# 
# cd $PATH_PROJECT
# 
# DIR=$(ls -d $PATH_PROJECT/posix-test/*/)
# VALAC="$PATH_PROJECT/usr/bin/valac --profile=posix --vapidir=$PATH_PROJECT/usr/share/vala-0.58/vapi/"
# export VALAC
# 
# for dir in $DIR; do
	# make --no-print-directory run -C $dir
	# if [ $? -ne 0 ]; then
		# echo "\033[31m[KO] $dir\033[0m"
	# else
		# echo "\033[32m[OK] $dir\033[0m"
	# fi
# done

echo "This script is deprecated. Please use the new test binary located in ./posix-test/test"
