# SPDX-License-Identifier: MPL-2.0
def blockingSpawn(*args)
	pid = spawn(*args)
	Process.wait pid
	if $?.exitstatus == 0
		return true
	else
		return false
	end
end

def compileAutoconf(pkgName, action, flags, globalVars, isRootfs=false)
	inBuild = false
	status = nil
	envVars = "PATH=#{globalVars["tcprefix"]}/bin:#{ENV["PATH"]}"
	if isRootfs == true
		envVars = "#{envVars} CC='#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]}' CFLAGS='-Os #{globalVars["cross_cflags"]}'"
	end

	if action == "configure" or (action == "compile" && flags.class == Array)
		confFlags = flags
		if flags.class == Array
			confFlags = flags[0]
		end

		Dir.chdir("#{globalVars["buildDir"]}/#{pkgName}-#{globalVars[pkgName]}")
		if File.exist?("build") == false
			Dir.mkdir("build")
			Dir.chdir("build")

			status = system("#{envVars} ../configure #{confFlags} 2>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
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
			if File.exist?("#{globalVars["buildDir"]}/#{pkgName}-#{globalVars[pkgName]}/build") == false
				errorHandler("Internal Error (package build directory not found). This is most likely a build system bug", false)
			end

			Dir.chdir(File.join(globalVars["buildDir"], "#{pkgName}-#{globalVars[pkgName]}/build"))
		end

		status = system("#{envVars} make #{compFlags} 2>>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
		if status == nil or status == false
			errorHandler("Package failed to compile", false)
		end
		Dir.chdir("#{globalVars["baseDir"]}")
	end
end

def compilePl32lib(pkgName, action, flags, globalVars)
	inBase = false
	status = nil
	if action == "configure" or (action == "compile" && flags.class == Array)
		confFlags = flags
		if flags.class == Array
			confFlags = flags[0]
		end

		Dir.chdir("#{globalVars["buildDir"]}/#{pkgName}-#{globalVars[pkgName]}")
		status = system("./configure #{confFlags} 2>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
		if status == nil or status == false
			errorHandler("Package failed to configure", false)
		end

		inBase = true
	end

	if action == "compile"
		compFlags = flags
		if flags.class == Array
			compFlags = flags[1]
		end

		if inBase == false
			Dir.chdir("#{globalVars["buildDir"]}/#{pkgName}-#{globalVars[pkgName]}")
		end

		status = system("./compile #{compFlags} 2>>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
		if status == nil or status == false
			errorHandler("Package failed to compile", false)
		end
		Dir.chdir("#{globalVars["baseDir"]}")
	end
end

def muslBuild(action, globalVars, isRootfs=false)
	muslParams = {"arch" => globalVars["linux_arch"], "installDir" => globalVars["sysroot"], "prefixToInstallDir" => ""}
	status = nil

	if globalVars["arch"] == "aarch64"
		muslParams["arch"] = globalVars["arch"]
	elsif globalVars["arch"].scan("riscv") != Array.new
		muslParams["arch"] = globalVars["arch"]
	end
	if isRootfs == true
		muslParams["installDir"] = "/usr"
		muslParams["prefixToInstallDir"] = "#{globalVars["outputDir"]}/rootfs/"
	end
	Dir.chdir("#{$buildDir}/musl-#{globalVars["musl"]}")

	case action
		when "headers"
			if File.exist?("#{muslParams["installDir"]}/include/stdio.h") == false
				system("make ARCH=#{muslParams["arch"]} prefix=#{muslParams["installDir"]} install-headers 2>#{globalVars["baseDir"]}/logs/headers-error.log >#{globalVars["baseDir"]}/logs/headers.log")
				Dir.chdir("#{$buildDir}/linux-#{globalVars["linux"]}")
				system("make ARCH=#{globalVars["linux_arch"]} INSTALL_HDR_PATH=#{muslParams["installDir"]} headers_install 2>>#{globalVars["baseDir"]}/logs/headers-error.log >>#{globalVars["baseDir"]}/logs/headers.log")
			end
		when "libc"
			if File.exist?("#{muslParams["prefixToInstallDir"]}#{muslParams["installDir"]}/lib/libc.so") == false
				muslArgs = Hash.new
				llvm_arch = "#{globalVars["linux_arch"]}"
				if globalVars["triple"].include? "eabihf"
					llvm_arch = "armhf"
				elsif globalVars["arch"] == "aarch64"
					llvm_arch = "aarch64"
				elsif globalVars["arch"].include? "riscv"
					llvm_arch = globalVars["arch"]
				end
				case globalVars["toolchain"]
					when "gcc"
						muslArgs.store("LIBCC", "#{globalVars["tcprefix"]}/lib/gcc/#{globalVars["triple"]}/#{globalVars["gcc"]}/libgcc.a")
						muslArgs.store("AR", "#{globalVars["tcprefix"]}/bin/#{globalVars["triple"]}-ar")
						muslArgs.store("RANLIB", "#{globalVars["tcprefix"]}/bin/#{globalVars["triple"]}-ranlib")
					when "llvm"
						muslArgs.store("LIBCC", "#{globalVars["sysroot"]}/lib/linux/libclang_rt.builtins-#{llvm_arch}.a")
						muslArgs.store("AR", "#{globalVars["tcprefix"]}/bin/llvm-ar")
						muslArgs.store("RANLIB", "#{globalVars["tcprefix"]}/bin/llvm-ranlib")
						muslArgs.store("CFLAGS", "#{globalVars["cross_cflags"]}")
				end
				muslArgs.store("CC", "#{globalVars["tcprefix"]}/bin/#{globalVars["cross_cc"]}")

				extraFlag = ""
				if isRootfs == true
					extraFlag = "--includedir=/opt/include"
				end

				status = blockingSpawn(muslArgs, "./configure --host=#{globalVars["triple"]} --prefix=#{muslParams["installDir"]} #{extraFlag} --disable-multilib 2>#{globalVars["baseDir"]}/logs/libc-error.log >#{globalVars["baseDir"]}/logs/libc.log")
				if status == nil or status == false
					errorHandler("Package failed to configure", false)
				end
				status = system("make AR=#{muslArgs["AR"]} RANLIB=#{muslArgs["RANLIB"]} 2>>#{globalVars["baseDir"]}/logs/libc-error.log >>#{globalVars["baseDir"]}/logs/libc.log")
				if status == nil or status == false
					errorHandler("Package failed to compile", false)
				end
				system("make DESTDIR=#{muslParams["prefixToInstallDir"]} install 2>>#{globalVars["baseDir"]}/logs/libc-error.log >>#{globalVars["baseDir"]}/logs/libc.log")
			end

			if File.exist?("#{globalVars["outputDir"]}/rootfs/bin/musl-clang")
				File.delete("#{globalVars["outputDir"]}/rootfs/bin/musl-clang")
				File.delete("#{globalVars["outputDir"]}/rootfs/bin/ld.musl-clang")
			end
	end
end
