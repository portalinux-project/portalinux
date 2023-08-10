require_relative 'common.rb'

$config = nil

def compileAutoconf(pkgName, action, flags)
	inBuild = false
	status = nil
	if action == "configure" or (action == "compile" && flags.class == Array)
		confFlags = flags
		if flags.class == Array
			confFlags = flags[0]
		end

		Dir.chdir(File.join($config["buildDir"], "#{pkgName}-#{$config[pkgName]}"))
		if File.exist?("build") == false
			Dir.mkdir("build")
			Dir.chdir("build")

			status = system("../configure #{confFlags} 2>#{$config["baseDir"]}/logs/#{pkgName}-error.log 1>#{$config["baseDir"]}/logs/#{pkgName}.log")
			if status == nil or status == false
				errorHandler("Package failed to configure", false)
			end
			inBuild = true
		end
	end

	if action == "compile"
		compFlags = flags
		if flags.class == Array
			compFlags = flags[1]
		end

		if inBuild == false
			if File.exist?("#{$config["buildDir"]}/#{pkgName}-#{$config[pkgName]}/build") == false
				errorHandler("Internal Error (package build directory not found). This is most likely a build system bug", false)
			end

			Dir.chdir(File.join($config["buildDir"], "#{pkgName}-#{$config[pkgName]}/build"))
		end

		status = system("make MAKEINFO=true #{compFlags} 2>>#{$config["baseDir"]}/logs/#{pkgName}-error.log 1>>#{$config["baseDir"]}/logs/#{pkgName}.log")
		if status == nil or status == false
			errorHandler("Package failed to configure", false)
		end
		Dir.chdir("#{$config["baseDir"]}")
	end
end

def toolchainSetup(config)
	$config = config
end

def toolchainBuild
	if File.exist?("#{$config["sysroot"]}/bin/as") == false
		print "Building Binutils..."
		compileAutoconf("binutils", "compile", [ "--prefix=#{$config["tcprefix"]} --target=#{$config["triple"]} --disable-werror", "-j#{$config["threads"]}" ])
		puts "Done."
		print "Installing Binutils..."
		compileAutoconf("binutils", "compile", "install-strip")
		puts "Done."
	end

	if File.exist?("#{$config["tcprefix"]}/lib/libmpc.so") == false
		print "Building GMP..."
		compileAutoconf("gmp", "compile", [ "--prefix=#{$config["tcprefix"]}", "-j#{$config["threads"]}" ])
		puts "Done."
		print "Installing GMP..."
		compileAutoconf("gmp", "compile", "install-strip")
		puts "Done."

		print "Building MPFR..."
		compileAutoconf("mpfr", "compile", [ "--prefix=#{$config["tcprefix"]} --with-gmp=#{$config["tcprefix"]}", "-j#{$config["threads"]}" ])
		puts "Done."
		print "Installing MPFR..."
		compileAutoconf("mpfr", "compile", "install-strip")
		puts "Done."

		print "Building MPC..."
		compileAutoconf("mpc", "compile", [ "--prefix=#{$config["tcprefix"]} --with-gmp=#{$config["tcprefix"]} --with-mpfr=#{$config["tcprefix"]}", "-j#{$config["threads"]}" ])
		puts "Done."
		print "Installing MPC..."
		compileAutoconf("mpc", "compile", "install-strip")
		puts "Done."
	end

	if File.exist?("#{$config["tcprefix"]}/bin/#{$config["triple"]}-gcc") == false
		print "Building GCC compilers..."
		compileAutoconf("gcc", "compile", [ "--prefix=#{$config["tcprefix"]} --target=#{$config["triple"]} --disable-werror --disable-libsanitizer --enable-initfini-array --enable-languages=c,c++ --disable-libstdcxx-debug --disable-bootstrap --with-gmp=#{$config["tcprefix"]} --with-mpfr=#{$config["tcprefix"]} --with-mpc=#{$config["tcprefix"]}", "-j#{$config["threads"]} all-gcc" ])
		puts "Done."
		print "Installing GCC compilers..."
		compileAutoconf("gcc", "compile", "install-strip-gcc")
		puts "Done."
	end

	if File.exist?("#{$config["sysroot"]}/include/stdio.h") == false
		print "Installing Linux and C library headers..."
		muslBuild("headers", $config, false)
		puts "Done."
	end

	if File.exist?("#{$config["tcprefix"]}/lib/gcc/#{$config["triple"]}/#{$config["gcc"]}/libgcc.a") == false
		print "Building libgcc-static..."
		compileAutoconf("gcc", "compile", [ "--prefix=#{$config["tcprefix"]} --target=#{$config["triple"]} --disable-werror --disable-libsanitizer --enable-initfini-array --enable-languages=c,c++ --disable-libstdcxx-debug --disable-bootstrap", "-j#{$config["threads"]} enable_shared=no all-target-libgcc" ])
		puts "Done."
		print "Installing libgcc-static..."
		compileAutoconf("gcc", "compile", "install-strip-target-libgcc")
		puts "Done."
	end
end
