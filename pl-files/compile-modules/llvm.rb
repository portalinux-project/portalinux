require_relative 'common.rb'

$llvmTargets="AArch64;ARM;BPF;Hexagon;LoongArch;Mips;PowerPC;RISCV;Sparc;SystemZ;X86"

def compileClang(pkgName, flags, globalVars)
	status = nil
	Dir.chdir("#{globalVars["buildDir"]}/#{pkgName}-#{globalVars[pkgName]}")

	if File.exist?("build-clang") == false
		Dir.mkdir("build-clang")
		Dir.chdir("build-clang")

		status = system("cmake ../llvm -GNinja #{flags} 2>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
		if status == nil or status != false
			errorHandler("Package failed to configure", false)
		end

		Dir.chdir("..")
	end

	Dir.chdir("build-clang")
	status = system("cmake --build . -j #{globalVars["threads"]} 2>>#{globalVars["baseDir"]}/logs/#{pkgName}-error.log 1>>#{globalVars["baseDir"]}/logs/#{pkgName}.log")
    if status == nil or status == false
        errorHandler("Package failed to build", false)
    end
end

def toolchainBuild globalVars
    if File.exist?("#{globalVars["tcprefix"]}/bin/clang") == false
		print "Building LLVM, Clang, LLD..."
		compileClang("llvm", "-DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX='#{globalVars["tcprefix"]}' -DLLVM_TARGETS_TO_BUILD='#{$llvmTargets}' -DLLVM_ENABLE_PROJECTS=clang;lld -DLLVM_HAVE_LIBXAR=0 -DLLVM_LINK_LLVM_DYLIB=1 -DCLANG_LINK_CLANG_DYLIB=1", globalVars)
		puts "Done."
		print "Installing LLVM, Clang, LLD..."
        installCMake("llvm", "--strip", globalVars, "build-clang")
		puts "Done."
	end

    errorHandler("Remaining LLVM support unimplemented.", false)
end
