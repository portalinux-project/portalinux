require_relative 'common.rb'

def rootfsBuild globalVars
	if Dir.exist?("#{globalVars["tcprefix"]}/#{globalVars["triple"]}") == false
		errorHandler("Toolchain for target #{globalVars["triple"]} not found. Please compile a toolchain and try again.", false)
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/lib") == false
		print "Creating rootfs structure..."
		for dir in [ "dev", "sys", "proc", "opt", "usr/bin", "usr/lib", "root", "mnt", "home", "tmp", "var/pl-srv" ]
			FileUtils.mkpath("#{globalVars["outputDir"]}/rootfs/#{dir}")
		end
		Dir.chdir("#{globalVars["outputDir"]}/rootfs")
		FileUtils.ln_s("./usr/bin", "usr/sbin")
		for dir in [ "bin", "sbin", "etc", "lib" ]
			FileUtils.ln_s("./usr/#{dir}", "#{dir}")
		end
		FileUtils.ln_s("/usr/bin/toybox", "usr/bin/sh")
		FileUtils.ln_s("/usr/bin/pl-init", "init")
		puts "Done"
		Dir.chdir("#{globalVars["baseDir"]}")
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/lib/libc.so") == false
		print "Building Musl..."
		muslBuild("libc", globalVars, true)
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/bin/toybox") == false
		print "Building Toybox..."
		Dir.chdir("#{globalVars["buildDir"]}/toybox-#{globalVars["toybox"]}")
		system("make defconfig 2>#{globalVars["baseDir"]}/logs/toybox-error.log >#{globalVars["baseDir"]}/logs/toybox.log")
		configFile = File.open(".config", "a")
		configFile.write("CONFIG_SH=y\nCONFIG_DD=y\nCONFIG_EXPR=y\nCONFIG_GETTY=y\nCONFIG_MDEV=y\n")
		configFile.close()
		system("make -j#{globalVars["threads"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS=#{globalVars["cross_cflags"]} 2>>#{globalVars["baseDir"]}/logs/toybox-error.log >>#{globalVars["baseDir"]}/logs/toybox.log")
		puts "Done"
		print "Installing Toybox..."
		FileUtils.move("toybox", "#{globalVars["outputDir"]}/rootfs/usr/bin")
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/lib/libpl32.so") == false
		print "Building pl32lib-ng..."
		compilePl32lib("pl32lib-ng", "compile", [ "--prefix=#{globalVars["outputDir"]}/rootfs/usr --includedir=#{globalVars["outputDir"]}/rootfs/opt/include --target=#{globalVars["triple"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS='-Os'", "build" ], globalVars)
		puts "Done."
		print "Installing pl32lib-ng..."
		compilePl32lib("pl32lib-ng", "compile", "install", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/lib/libplml.so") == false
		print "Building libplml..."
		compilePl32lib("libplml", "compile", [ "--prefix=#{globalVars["outputDir"]}/rootfs/usr --includedir=#{globalVars["outputDir"]}/rootfs/opt/include --target=#{globalVars["triple"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS='-Os'", "build" ], globalVars)
		puts "Done."
		print "Installing libplml..."
		compilePl32lib("libplml", "compile", "install", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/bin/pl-init") == false
		print "Building pl-srv..."
		compilePl32lib("pl-srv", "compile", [ "--prefix=#{globalVars["outputDir"]}/rootfs/usr --includedir=#{globalVars["outputDir"]}/rootfs/opt/include --target=#{globalVars["triple"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS='-Os'", "build" ], globalVars)
		puts "Done."
		print "Installing pl-srv..."
		compilePl32lib("pl-srv", "compile", "install", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/etc") == false
		print "Installing etc files..."

		Dir.mkdir("#{globalVars["outputDir"]}/rootfs/usr/etc")
		FileUtils.copy_entry("#{globalVars["rootfsFilesDir"]}/etc", "#{globalVars["outputDir"]}/rootfs/usr/etc")

		tmpFile = File.open("#{globalVars["rootfsFilesDir"]}/etc/issue", "w")
		tmpFile.seek(11)
		tmpFile.write("#{globalVars["version"]}")
		tmpFile.close()

		muslArch = globalVars["linux_arch"]
		if muslArch == "arm64"
			muslArch = "aarch64"
		end
		File.rename("#{globalVars["outputDir"]}/rootfs/usr/etc/ld-musl.path", "#{globalVars["outputDir"]}/rootfs/usr/etc/ld-musl-#{muslArch}.path")

		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/bin/pl-info") == false
		print "Installing PortaLinux Scripts..."
		FileUtils.copy([ "#{globalVars["rootfsFilesDir"]}/usr-bin/init-script", "#{globalVars["rootfsFilesDir"]}/usr-bin/pl-install", "#{globalVars["rootfsFilesDir"]}/usr-bin/pl-info" ], "#{globalVars["outputDir"]}/rootfs/usr/bin")
		FileUtils.chmod(0777, [ "#{globalVars["outputDir"]}/rootfs/usr/bin/init-script", "#{globalVars["outputDir"]}/rootfs/usr/bin/pl-install", "#{globalVars["outputDir"]}/rootfs/usr/bin/pl-info" ])
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/lib/os-release") == false
		print "Installing os-release..."
		FileUtils.copy("#{globalVars["rootfsFilesDir"]}/usr-lib/os-release", "#{globalVars["outputDir"]}/rootfs/usr/lib")
		tmpFile = File.open("#{globalVars["outputDir"]}/rootfs/usr/lib/os-release", "a")
		tmpFile.write("#{Time.now.to_i}")
		tmpFile.close()
		puts "Done."
	end
end
