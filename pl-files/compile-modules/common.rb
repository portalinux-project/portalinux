# SPDX-License-Identifier: MPL-2.0
def errorHandler(msg, isDeveloperBug)
	puts "Error: #{msg}."
	if isDeveloperBug == true
		puts "If you're seeing this, this is a bug. Please report this bug to the maintainers of this PortaLinux repository"
	end
	exit 1
end

def blockingSpawn(*args)
	pid = spawn(*args)
	Process.wait pid
end

def muslBuild(action, globalVars, isRootfs=false)
	muslParams = {"arch" => globalVars["linux_arch"], "installDir" => globalVars["sysroot"], "prefixToInstallDir" => ""}

	if globalVars["arch"] == "aarch64"
		muslParams["arch"] = globalVars["arch"]
	end
	if isRootfs == true
		muslParams["installDir"] = "/usr"
	end
	Dir.chdir("#{$buildDir}/musl-#{globalVars["musl"]}")

	case action
		when "headers"
			if File.exist?("#{muslParams["installDir"]}/include/stdio.h") == false
				system("make ARCH=#{muslParams["arch"]} prefix=#{globalVars["sysroot"]} install-headers")
				Dir.chdir("#{$buildDir}/#{getPkgInfo("linux", "dir")}")
				system("make ARCH=#{globalVars["linux_arch"]} INSTALL_HDR_PATH=#{globalVars]} headers_install")
			end
		when "libc"
			if File.exist?("#{installPath}/lib/libc.so") == false
				muslArgs Hash.new
				case globalVars["toolchain"]
					when "gcc"
						muslArgs.merge!("LIBCC" => "#{globalVars["tcprefix"]}/lib/gcc/#{globalVars["triple"]}/#{globalVars["gcc"]}/libgcc.a")
						muslArgs.merge!("AR" => "#{globalVars["tcprefix"]}/bin/#{globalVars["triple"]}-ar")
						muslArgs.merge!("RANLIB" => "#{globalVars["tcprefix"]}/bin/#{globalVars["triple"]}-ranlib")
					when "llvm"
						muslArgs.merge!("LIBCC" => "#{globalVars["sysroot"]}/lib/linux/libclang_rt.builtins-#{globalVars["linux_arch"]}.a")
						muslArgs.merge!("AR" => "#{globalVars["tcprefix"]}/bin/llvm-ar")
						muslArgs.merge!("RANLIB" => "#{globalVars["tcprefix"]}/bin/llvm-ranlib")
				end

				blockingSpawn(muslArgs, "LIBCC=#{muslArgs["LIBCC"]} AR=#{muslArgs["AR"]} RANLIB=#{muslArgs["RANLIB"]} ./compile --host=#{globalVars["triple"]} --prefix=#{muslParams["installDir"]} --disable-multilib")
				system("make AR=#{muslArgs["AR"]} RANLIB=#{muslArgs["RANLIB"]}")
				system("make DESTDIR=#{muslParams["prefixToInstallDir"]} install")
			end
	end
end
