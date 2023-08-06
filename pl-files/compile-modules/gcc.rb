$config = nil

def compileAutoconf(pkgName, action, flags)
	if action == "configure" or (action == "compile" && flags.class == Array)
		confFlags = flags
		if flags.class == Array
			confFlags = flags[0]
		end

		Dir.chdir(File.join($config["buildDir"], "#{pkgName}-#{config[pkgName]}"))
		if File.exist?("build") == false
			Dir.mkdir("build")
			Dir.chdir("build")

			system("../configure #{confFlags}")
		end
	end

	if action == "compile"
		compFlags = flags
		if flags.class == Array
			compFlags = flags[1]
			Dir.chdir("build")
		else
			if File.exist?("#{$config["buildDir"]}/#{pkgName}-#{config[pkgName]}/build")
				errorHandler("Internal Error (package build directory not found). This is most likely a build system bug", false)
			end

			Dir.chdir(File.join($config["buildDir"], "#{pkgName}-#{config[pkgName]}/build"))
		end

		system("make #{compFlags}")
	end
end

def toolchainSetup(config)
	$config = config
end

def toolchainBuild
	exit 0
end
