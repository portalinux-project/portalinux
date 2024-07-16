require 'common'

def rootfsBuild globalVars
	if Dir.exist?("#{globalVars["tcprefix"]}/#{globalVars["triple"]}") == false
		errorHandler("Toolchain for target #{globalVars["triple"]} not found. Please compile a toolchain and try again", false)
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/lib") == false
		print "Creating rootfs structure..."
		for dir in [ "dev", "sys", "proc", "opt", "usr/bin", "usr/lib", "root", "mnt", "home", "tmp", "var/pl-srv/srv", "var/log" ]
			FileUtils.mkpath("#{globalVars["outputDir"]}/rootfs/#{dir}")
		end
		Dir.chdir("#{globalVars["outputDir"]}/rootfs")
		FileUtils.ln_s("./bin", "usr/sbin")
		for dir in [ "bin", "sbin", "etc", "lib" ]
			FileUtils.ln_s("./usr/#{dir}", "#{dir}")
		end
		FileUtils.ln_s("/usr/bin/dash", "usr/bin/sh")
		FileUtils.ln_s("/usr/bin/pl-init", "init")
		puts "Done"
		Dir.chdir("#{globalVars["baseDir"]}")
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/lib/libc.so") == false
		print "Building Musl..."
		muslBuild("libc", globalVars, true)
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/lib/libz.so") == false
		print "Building zlib..."
		Dir.chdir("#{globalVars["buildDir"]}/zlib-#{globalVars["zlib"]}")
		if File.exist?("build") == false
			Dir.mkdir("build")
		end
		Dir.chdir("build")
		blockingSpawn({"CC" => "#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]}", "AR" => "#{globalVars["tcprefix"]}/bin/#{globalVars["triple"]}-ar"}, "../configure --prefix=/usr --includedir=/opt/include 2>#{globalVars["baseDir"]}/logs/zlib-error.log 1>#{globalVars["baseDir"]}/logs/zlib.log");
		blockingSpawn("make -j#{globalVars["threads"]} 2>#{globalVars["baseDir"]}/logs/zlib-error.log 1>#{globalVars["baseDir"]}/logs/zlib.log");
		puts "Done."
		print "Installing zlib..."
		blockingSpawn("make install DESTDIR=#{globalVars["outputDir"]}/rootfs 2>#{globalVars["baseDir"]}/logs/zlib-error.log 1>#{globalVars["baseDir"]}/logs/zlib.log")
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/bin/toybox") == false
		print "Building Toybox..."
		Dir.chdir("#{globalVars["buildDir"]}/toybox-#{globalVars["toybox"]}")
		system("make defconfig 2>#{globalVars["baseDir"]}/logs/toybox-error.log >#{globalVars["baseDir"]}/logs/toybox.log")
		configFile = File.open(".config", "a")
		configFile.write("CONFIG_EXPR=y\nCONFIG_GETTY=y\nCONFIG_MDEV=y\nCONFIG_TOYBOX_LIBZ=y\nCONFIG_XZCAT=y\nCONFIG_FSCK=y\nCONFIG_MKE2FS=y\nCONFIG_MKE2FS_JOURNAL=y\nCONFIG_PASSWD=y\nCONFIG_GZIP=y\n")
		configFile.close()
		if system("make -j#{globalVars["threads"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS=#{globalVars["cross_cflags"]} 2>>#{globalVars["baseDir"]}/logs/toybox-error.log >>#{globalVars["baseDir"]}/logs/toybox.log") != true
			errorHandler("Toybox failed to compile", false)
		end
		puts "Done"
		print "Installing Toybox..."
		FileUtils.move("toybox", "#{globalVars["outputDir"]}/rootfs/usr/bin")
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/bin/dash") == false
		print "Building Dash..."
		Dir.chdir("#{globalVars["buildDir"]}/dash-#{globalVars["dash"]}")
		system("./autogen.sh 1>#{globalVars["baseDir"]}/logs/dash-autogen.log 2>#{globalVars["baseDir"]}/logs/dash-autogen-error.log")
		compileAutoconf("dash", "compile", [ "--prefix=/usr --host=#{globalVars["triple"]} --datarootdir=/opt", "-j#{globalVars["threads"]}" ], globalVars, true)
		puts "Done."
		print "Installing Dash..."
		compileAutoconf("dash", "compile", "install DESTDIR=#{globalVars["outputDir"]}/rootfs", globalVars, true)
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/lib/libplrt.so") == false
		print "Building pl-rt..."
		compilePl32lib("pl-rt", "compile", [ "--prefix=#{globalVars["outputDir"]}/rootfs/usr --includedir=#{globalVars["outputDir"]}/rootfs/opt/include --target=#{globalVars["triple"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS='-Os'", "build" ], globalVars)
		puts "Done."
		print "Installing pl-rt..."
		compilePl32lib("pl-rt", "compile", "install", globalVars)
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/lib/libplterm.so") == false
		print "Building pltermlib..."
		compilePl32lib("pltermlib", "compile", [ "--prefix=#{globalVars["outputDir"]}/rootfs/usr --includedir=#{globalVars["outputDir"]}/rootfs/opt/include --target=#{globalVars["triple"]} CC=#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} CFLAGS='-Os'", "build" ], globalVars)
		puts "Done."
		print "Installing pltermlib..."
		compilePl32lib("pltermlib", "compile", "install", globalVars)
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
		muslArch = globalVars["linux_arch"]
		if muslArch == "arm64"
			muslArch = "aarch64"
		end
		File.rename("#{globalVars["outputDir"]}/rootfs/usr/etc/ld-musl.path", "#{globalVars["outputDir"]}/rootfs/usr/etc/ld-musl-#{muslArch}.path")
		FileUtils.chmod(0777, "#{globalVars["outputDir"]}/rootfs/usr/etc/pl-srv/basic-startup")
		Dir.mkdir("#{globalVars["outputDir"]}/rootfs/usr/etc/keymaps")

		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs/usr/bin/plkeyb") == false
		print "Installing PortaLinux Utilities..."
		system("#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]} #{globalVars["cross_cflags"]} #{globalVars["rootfsFilesDir"]}/usr-bin/plkeyb.c -o #{globalVars["outputDir"]}/rootfs/usr/bin/plkeyb")
		FileUtils.copy([ "#{globalVars["rootfsFilesDir"]}/usr-bin/shell-respawn", "#{globalVars["rootfsFilesDir"]}/usr-bin/enable-persistence", "#{globalVars["rootfsFilesDir"]}/usr-bin/pl-install", "#{globalVars["rootfsFilesDir"]}/usr-bin/pl-info", "#{globalVars["rootfsFilesDir"]}/usr-bin/pl-setup", "#{globalVars["rootfsFilesDir"]}/usr-bin/automount", "#{globalVars["rootfsFilesDir"]}/usr-bin/ls" ], "#{globalVars["outputDir"]}/rootfs/usr/bin")
		FileUtils.chmod(0777, [ "#{globalVars["outputDir"]}/rootfs/usr/bin/shell-respawn",  "#{globalVars["outputDir"]}/rootfs/usr/bin/enable-persistence", "#{globalVars["outputDir"]}/rootfs/usr/bin/pl-install", "#{globalVars["outputDir"]}/rootfs/usr/bin/pl-info", "#{globalVars["outputDir"]}/rootfs/usr/bin/pl-setup", "#{globalVars["outputDir"]}/rootfs/usr/bin/automount", "#{globalVars["outputDir"]}/rootfs/usr/bin/ls" ])
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

def bootImgMaker globalVars
	if Dir.exist?("#{globalVars["outputDir"]}/rootfs") == false
		errorHandler("Root filesystem not found. Please compile a PortaLinux root filesystem and try again", false)
	end

	if File.exist?("#{globalVars["outputDir"]}/pl-base-dev.plpak") == false
		print "Creating pl-base-dev package..."
		Dir.chdir("#{globalVars["outputDir"]}")
		FileUtils.mkpath("pl-base-dev/files/opt/lib")
		FileUtils.move(Dir.glob("rootfs/opt/*"), "pl-base-dev/files/opt")
		FileUtils.move(Dir.glob("rootfs/lib/*.a"), "pl-base-dev/files/opt/lib")
		FileUtils.move(Dir.glob("rootfs/lib/*.o"), "pl-base-dev/files/opt/lib")
		FileUtils.move("rootfs/usr/share/man", "pl-base-dev/files/opt/share", force: true)
		Dir.chdir("pl-base-dev")
		system("tar cf files.tar files")
		configFile = open("pkg_info", "w")
		configFile.write("pkg_name=pl-base-dev\n")
		configFile.write("pkg_ver=0.11\n")
		configFile.write("pkg_arch=#{globalVars["arch"]}\n")
		configFile.close()
		FileUtils.rm_rf("files")
		system("sha256sum files.tar > files.tar.sha256sum")
		system("tar cf ../pl-base-dev.tar files.tar files.tar.sha256sum pkg_info")
		Dir.chdir("..")
		system("gzip pl-base-dev.tar")
		FileUtils.rm_rf("pl-base-dev")
		File.rename("pl-base-dev.tar.gz", "pl-base-dev.plpak")
		Dir.chdir("#{globalVars["baseDir"]}")
		puts "Done."
	end

	if File.exist?("#{globalVars["outputDir"]}/rootfs.cpio.gz") == false
		printf "Creating device nodes..."
		if Process.uid != 0
			sudoProg = ""
			if File.exist?("/run/wrappers/bin/sudo")
				sudoProg = "/run/wrappers/bin/sudo"
			elsif File.exist?("/usr/bin/sudo")
				sudoProg = "/usr/bin/sudo"
			elsif File.exist?("/bin/sudo")
				sudoProg = "/bin/sudo"
			else
				errorHandler("Cannot escalate priviledges. Run this program as the superuser and try again")
			end

			system("#{sudoProg} #{globalVars["baseDir"]}/lib/mknod.sh #{globalVars["outputDir"]}/rootfs")
		else
			system("#{globalVars["baseDir"]}/lib/mknod.sh #{globalVars["outputDir"]}/rootfs")
		end
		puts "Done."
		print "Generating boot image..."
		Dir.chdir("#{globalVars["outputDir"]}/rootfs")
		system("find . | cpio -H newc -ov > ../rootfs.cpio 2>/dev/null")
		system("gzip ../rootfs.cpio")
		puts "Done."
	end
end
