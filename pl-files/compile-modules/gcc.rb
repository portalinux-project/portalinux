require_relative 'common.rb'

def toolchainBuild globalVars
	if File.exist?("#{globalVars["sysroot"]}/bin/as") == false
		print "Building Binutils..."
		compileAutoconf("binutils", "compile", [ "--prefix=#{globalVars["tcprefix"]} --target=#{globalVars["triple"]} --disable-werror", "-j#{globalVars["threads"]}" ], globalVars)
		puts "Done."
		print "Installing Binutils..."
		compileAutoconf("binutils", "compile", "install-strip", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["tcprefix"]}/lib/libmpc.so") == false
		print "Building GMP..."
		compileAutoconf("gmp", "compile", [ "--prefix=#{globalVars["tcprefix"]}", "-j#{globalVars["threads"]}" ], globalVars)
		puts "Done."
		print "Installing GMP..."
		compileAutoconf("gmp", "compile", "install-strip", globalVars)
		puts "Done."

		print "Building MPFR..."
		compileAutoconf("mpfr", "compile", [ "--prefix=#{globalVars["tcprefix"]} --with-gmp=#{globalVars["tcprefix"]}", "-j#{globalVars["threads"]}" ], globalVars)
		puts "Done."
		print "Installing MPFR..."
		compileAutoconf("mpfr", "compile", "install-strip", globalVars)
		puts "Done."

		print "Building MPC..."
		compileAutoconf("mpc", "compile", [ "--prefix=#{globalVars["tcprefix"]} --with-gmp=#{globalVars["tcprefix"]} --with-mpfr=#{globalVars["tcprefix"]}", "-j#{globalVars["threads"]}" ], globalVars)
		puts "Done."
		print "Installing MPC..."
		compileAutoconf("mpc", "compile", "install-strip", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["tcprefix"]}/bin/#{globalVars["triple"]}-gcc") == false
		print "Building GCC compilers..."
		compileAutoconf("gcc", "compile", [ "--prefix=#{globalVars["tcprefix"]} --target=#{globalVars["triple"]} --disable-werror --disable-libsanitizer --enable-initfini-array --enable-languages=c,c++ --disable-libstdcxx-debug --disable-bootstrap --with-gmp=#{globalVars["tcprefix"]} --with-mpfr=#{globalVars["tcprefix"]} --with-mpc=#{globalVars["tcprefix"]}", "-j#{globalVars["threads"]} all-gcc" ], globalVars)
		puts "Done."
		print "Installing GCC compilers..."
		compileAutoconf("gcc", "compile", "install-strip-gcc", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["sysroot"]}/include/stdio.h") == false
		print "Installing Linux and C library headers..."
		muslBuild("headers", globalVars, false)
		puts "Done."
	end

	if File.exist?("#{globalVars["tcprefix"]}/lib/gcc/#{globalVars["triple"]}/#{globalVars["gcc"]}/libgcc.a") == false
		print "Building libgcc-static..."
		compileAutoconf("gcc", "compile", [ "--prefix=#{globalVars["tcprefix"]} --target=#{globalVars["triple"]} --disable-werror --disable-libsanitizer --enable-initfini-array --enable-languages=c,c++ --disable-libstdcxx-debug --disable-bootstrap", "-j#{globalVars["threads"]} enable_shared=no all-target-libgcc" ], globalVars)
		puts "Done."
		print "Installing libgcc-static..."
		compileAutoconf("gcc", "compile", "install-strip-target-libgcc", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["sysroot"]}/lib/libc.so") == false
		print "Building Musl..."
		muslBuild("libc", globalVars, false)
		puts "Done."
	end

	if File.exist?("#{globalVars["sysroot"]}/lib/libgcc_s.so") == false
		print "Cleaning libgcc..."
		compileAutoconf("gcc", "compile", [ "--prefix=#{globalVars["tcprefix"]} --target=#{globalVars["triple"]} --disable-werror --disable-libsanitizer --enable-initfini-array --enable-languages=c,c++ --disable-libstdcxx-debug --disable-bootstrap", "-C #{globalVars["triple"]}/libgcc distclean" ], globalVars)
		puts "Done."
		print "Building libgcc-shared..."
		compileAutoconf("gcc", "compile", "-j#{globalVars["threads"]} enable_shared=yes all-target-libgcc", globalVars)
		puts "Done."
		print "Installing libgcc-shared..."
		compileAutoconf("gcc", "compile", "install-strip-target-libgcc", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["sysroot"]}/lib/libstdc++.so") == false
		print "Building libstdc++..."
		compileAutoconf("gcc", "compile", [ "--prefix=#{globalVars["tcprefix"]} --target=#{globalVars["triple"]} --disable-werror --disable-libsanitizer --enable-initfini-array --enable-languages=c,c++ --disable-libstdcxx-debug --disable-bootstrap", "-j#{globalVars["threads"]}" ], globalVars)
		puts "Done."
		print "Installing libstdc++..."
		compileAutoconf("gcc", "compile", "install-strip-target-libstdc++-v3", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["sysroot"]}/lib/libpl32.so") == false
		print "Building pl32lib-ng..."
		compilePl32lib("pl32lib-ng", "compile", [ "--prefix=#{globalVars["sysroot"]} --target=#{globalVars["triple"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS='-Os'", "build" ], globalVars)
		puts "Done."
		print "Installing pl32lib-ng..."
		compilePl32lib("pl32lib-ng", "compile", "install", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["sysroot"]}/lib/libplml.so") == false
		print "Building libplml..."
		compilePl32lib("libplml", "compile", [ "--prefix=#{globalVars["sysroot"]} --target=#{globalVars["triple"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS='-Os'", "build" ], globalVars)
		puts "Done."
		print "Installing libplml..."
		compilePl32lib("libplml", "compile", "install", globalVars)
		puts "Done."
	end
end
