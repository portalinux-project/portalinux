# SPDX-License-Identifier: MPL-2.0

#_compile_cmake_pkg 1)fileToCheckIfExists 2)mainProjectDir 3)projectToConfig 4)buildSubDir(optional)
#                   5)installPrefix 6)cmakeArgs 7)projectName 8)noCleanBuildDir(optional) 9)noSilentBuild(optional)
_compile_cmake_pkg(){
	if [ ! -r "$1" ]; then
		cd "$2"
		if [ "$8" = "" ]; then
			rm -rf "build/$4"
		fi

		# arg parser
		_args=""
		for i in $6; do
			_args="$_args -D$i"
		done

		# configure the project
		_exec "Configuring $7"			"cmake -S './$3' -B 'build/$4' -GNinja -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX='$5' $_args"
		if [ "$9" = "" ]; then
			_exec "Compiling $7"		"cmake --build 'build/$4' -j$threads"
		else
			_exec "Compiling $7...\n"	"cmake --build 'build/$4' -j$threads" no-silent
		fi
		_exec "Installing $7"			"cmake --install 'build/$4' --strip"
	fi
}
