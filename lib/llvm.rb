require 'common'

$llvmTargets="AArch64;ARM;BPF;Hexagon;LoongArch;Mips;PowerPC;RISCV;Sparc;SystemZ;X86"

def installCMake(pkgName, flags, globalVars, cmakeDir)
	status = nil
		Dir.chdir("#{globalVars["buildDir"]}/#{pkgName}-#{globalVars[pkgName]}")

	if File.exist?(cmakeDir) == false
			errorHandler("Internal Error (package build directory not found). This is most likely a build system bug", false)
		end

	Dir.chdir(cmakeDir)
	status = system("cmake --install . #{flags} 2>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
	if status == nil or status == false
		errorHandler("Package failed to install", false)
	end
end

def compileClang(pkgName, flags, globalVars)
	status = nil
	Dir.chdir("#{globalVars["buildDir"]}/#{pkgName}-#{globalVars[pkgName]}")

	if File.exist?("build-clang") == false
		Dir.mkdir("build-clang")
		Dir.chdir("build-clang")

		status = system("cmake ../llvm -GNinja #{flags} 2>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
		if status == nil
			Dir.chdir("..")
			FileUtils.rm_rf("build-clang")
			errorHandler("Package failed to configure", false)
		end

		Dir.chdir("..")
	end

	Dir.chdir("build-clang")
	status = system("cmake --build . -j#{globalVars["threads"]} 2>>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log | tee #{globalVars["baseDir"]}/logs/#{pkgName}.log")
	if status == nil or status == false
		errorHandler("Package failed to build", false)
	end
end

def compileLLVMLibs(pkgName, buildDir, flags, globalVars)
	status = nil
	Dir.chdir("#{globalVars["buildDir"]}/llvm-#{globalVars["llvm"]}")

	if File.exist?("build-#{pkgName}") == true
		FileUtils.rm_rf("build-#{pkgName}")
	end

	Dir.mkdir("build-#{pkgName}")
	Dir.chdir("build-#{pkgName}")

	status = system("cmake ../#{buildDir} -GNinja #{flags} 2>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
	if status == nil
		Dir.chdir("..")
		FileUtils.rm_rf("build-#{pkgName}")
		errorHandler("Package failed to configure", false)
	end

	status = system("cmake --build . -j#{globalVars["threads"]} 2>>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log | tee #{globalVars["baseDir"]}/logs/#{pkgName}.log")
	if status == nil or status == false
		errorHandler("Package failed to build", false)
	end
end

def createCMakeToolchainFile(globalVars, crossfile)
	crossdata = <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR "#{globalVars["arch"]}")
set(CMAKE_SYSROOT "#{globalVars["sysroot"]}")

set(triple "#{globalVars["triple"]}")
set(CMAKE_ASM_COMPILER_TARGET ${triple})
set(CMAKE_C_COMPILER_TARGET ${triple})
set(CMAKE_CXX_COMPILER_TARGET ${triple})

set(CMAKE_C_COMPILER "#{globalVars["tcprefix"]}/bin/clang")
set(CMAKE_CXX_COMPILER "#{globalVars["tcprefix"]}/bin/clang++")
set(CMAKE_NM "#{globalVars["tcprefix"]}/bin/llvm-nm")
set(CMAKE_AR "#{globalVars["tcprefix"]}/bin/llvm-ar")
set(CMAKE_RANLIB "#{globalVars["tcprefix"]}/bin/llvm-ranlib")


# these variables tell CMake to avoid using any binary it finds in
# the sysroot, while picking headers and libraries exclusively from it
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF
	File.write(crossfile, crossdata)
end

def toolchainBuild globalVars
	if File.exist?("#{globalVars["tcprefix"]}/bin/clang") == false
		print "Building LLVM, Clang, LLD..."
		compileClang("llvm", "-DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX='#{globalVars["tcprefix"]}' -DLLVM_TARGETS_TO_BUILD='#{$llvmTargets}' -DLLVM_ENABLE_PROJECTS='clang;lld' -DLLVM_HAVE_LIBXAR=0 -DLLVM_LINK_LLVM_DYLIB=1 -DCLANG_LINK_CLANG_DYLIB=1", globalVars)
		print "Done. Installing LLVM, Clang, LLD..."
		installCMake("llvm", "--strip", globalVars, "build-clang")
		puts "Done."
	end

	if File.exist?("#{globalVars["sysroot"]}/include/stdio.h") == false
		print "Installing Linux and C library headers..."
		muslBuild("headers", globalVars, false)
		puts "Done."
	end

	if File.exist?("#{globalVars["sysroot"]}/cross.cmake") == false
		createCMakeToolchainFile(globalVars, "#{globalVars["sysroot"]}/cross.cmake")
	end

	if File.exist?("#{globalVars["sysroot"]}/lib/linux/libclang_rt.builtins-#{globalVars["linux_arch"]}.a") == false
		print "Building LLVM builtins..."
		compileLLVMLibs("builtins", "compiler-rt", "-DCMAKE_TOOLCHAIN_FILE='#{globalVars["sysroot"]}/cross.cmake' -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY -DCMAKE_INSTALL_PREFIX='#{globalVars["sysroot"]}' -DCOMPILER_RT_BUILD_LIBFUZZER=0 -DCOMPILER_RT_BUILD_MEMPROF=0 -DCOMPILER_RT_BUILD_ORC=0 -DCOMPILER_RT_BUILD_PROFILE=0 -DCOMPILER_RT_BUILD_SANITIZERS=0 -DCOMPILER_RT_BUILD_XRAY=0 -DCOMPILER_RT_DEFAULT_TARGET_ONLY=1", globalVars)
		print "Done.\nInstalling LLVM builtins..."
		installCMake("llvm", "--strip", globalVars, "build-builtins")
		puts "Done."
	end

	errorHandler("Remaining LLVM support unimplemented.", false)
end
