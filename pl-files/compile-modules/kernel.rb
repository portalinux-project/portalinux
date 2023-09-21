require_relative 'common.rb'

def kernelBuild globalVars
	Dir.chdir("#{globalVars["buildDir"]}/linux-#{globalVars["linux"]}")

	moduleSupport = false
	extraKernelFlags = ""
	oldPath = ENV["PATH"]
	ENV["PATH"] = "#{globalVars["tcprefix"]}/bin:#{ENV["PATH"]}"
	if globalVars["toolchain"] == "llvm"
		extraKernelFlags = "HOSTCC=cc HOSTLD=ld LLVM=#{globalVars["tcprefix"]}/bin"
	end

	if File.exist?(".config") == false
		print "Please input default configuration: "
		defconfig = gets.chomp
		if defconfig == "" or defconfig == nil
			defconfig = "defconfig"
		end

		system("make ARCH=#{globalVars["linux_arch"]} #{defconfig}")
		print "Would you like to configure further? (N/y) "
		yn = gets.chomp
		if yn == "y" or yn == "yes" or yn == "Y"
			system("make menuconfig")
		end

		matches = File.foreach(".config").grep("CONFIG_MODULES")
		if matches != Array.new
			moduleSupport = true
		end
	end

	puts "Compiling kernel..."
	system("make -j#{globalVars["threads"]} #{extraKernelFlags} CROSS_COMPILE=#{globalVars["triple"]}- ARCH=#{globalVars["linux_arch"]} -j#{globalVars["threads"]}")
	puts "Installing kernel files..."

	Dir.chdir("#{globalVars["buildDir"]}/linux-#{globalVars["linux"]}/arch/#{globalVars["linux_arch"]}/boot")
	realPath = File.readlink(Dir.foreach(".").grep(/Image/).shift)
	FileUtils.copy(realPath, "#{globalVars["outputDir"]}")

	Dir.chdir(File.dirname(realPath))
	if Dir.exist?("dts")
		FileUtils.copy_entry("dts", "#{globalVars["outputDir"]}")
	end

	Dir.chdir("../../..")
	if moduleSupport == true
		system("make ARCH=#{globalVars["linux_arch"]} INSTALL_MOD_PATH=#{globalVars["outputDir"]}/rootfs modules_install")
	end
	ENV["PATH"] = oldPath

	Dir.chdir("#{globalVars["baseDir"]}")
end
