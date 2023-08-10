# SPDX-License-Identifier: MPL-2.0
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
		muslParams["prefixToInstallDir"] = "#{globalVars[outputDir]}/rootfs"
	end
	Dir.chdir("#{$buildDir}/musl-#{globalVars["musl"]}")

	case action
		when "headers"
			if File.exist?("#{muslParams["installDir"]}/include/stdio.h") == false
				system("make ARCH=#{muslParams["arch"]} prefix=#{globalVars["sysroot"]} install-headers")
				Dir.chdir("#{$buildDir}/#{getPkgInfo("linux", "dir")}")
				system("make ARCH=#{globalVars["linux_arch"]} INSTALL_HDR_PATH=#{globalVars["sysroot"]} headers_install")
			end
		when "libc"
			if File.exist?("#{}/lib/libc.so") == false
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

				blockingSpawn(muslArgs, "./configure --host=#{globalVars["triple"]} --prefix=#{muslParams["installDir"]} --disable-multilib")
				system("make AR=#{muslArgs["AR"]} RANLIB=#{muslArgs["RANLIB"]}")
				system("make DESTDIR=#{muslParams["prefixToInstallDir"]} install")
			end
	end
end
