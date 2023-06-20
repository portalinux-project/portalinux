def compile_autoconf(pkgName, action, flags){
	dir = getPkgDir(pkgName)

	if action == "configure" or (action == "compile" && flags.class == Array)
		confFlags = flags
		if flags.class == Array
			confFlags = flags[0]
		end

		Dir.chdir("#{$}")
}
