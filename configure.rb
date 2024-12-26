#!/usr/bin/env ruby
# SPDX-License-Identifier: MPL-2.0

require 'plml/plml'
require 'net/http'

$supportedArches = nil
$arch = nil
$preset = nil
$prefix = File.expand_path("~/cross")
$baseDir = File.expand_path(".")
$configDir = "#{$baseDir}/pl-files/configure-files"

def errorHandler(msg, isOpt)
	print "Error: #{msg}."
	if isOpt == true
		puts " Run #{$0} -h for more information"
	end
	exit 1
end

def downloadFile(url, file, secure)
	if File.exist?(file) == true
		puts "#{File.basename(file)} exists, skipping..."
		return
	end

	print "Downloading #{File.basename(file)}..."

	uri = URI(url)
	port = 80
	if secure == true
		port = 443
	end

	connection = Net::HTTP.new(uri.host, port)
	connection.use_ssl = secure
	response = connection.get(uri.path)
	if response.code.to_i >= 400
		errorHandler(response.body, false)
	end
	downloadedFile = File.open(file, "wb")
	downloadedFile.write(response.body)
	downloadedFile.close

	puts "Done."
end

def fetchPkgs pkgList
	for i in pkgList
		fileParse = PLML.load_file("#{$configDir}/pkg/#{i}.plml")
		use_secure = false
		final_url = fileParse["url"]
		final_filename = "#{File.basename final_url}"
		if fileParse["url"].match?("https") == true or fileParse["github"] == true
			use_secure = true
			if fileParse["github"] == true
				final_filename = "#{fileParse["name"]}-#{fileParse["version"]}"
				final_url = "https://codeload.github.com/#{fileParse["url"]}/tar.gz/refs/"
				if fileParse["tag"] == nil
					final_url = final_url + "heads/"
					if fileParse["branch"] == nil
						final_url = final_url + "main"
					else
						final_url = final_url + fileParse["branch"]
					end
				else
					final_url = final_url + "tags/" + fileParse["tag"]
				end
			end
		end

		downloadFile(final_url, "#{$baseDir}/tarballs/#{final_filename}", use_secure)
	end
end

def decompressPkgs
	if Dir.empty?("#{$baseDir}/build") == false
		puts "Build directory is not empty. Skipping decompression stage..."
		return
	end

	openDir = Dir.open("#{$baseDir}/tarballs")

	for i in openDir.each_child
		print "Decompressing #{i}..."

		splitChild = i.split(".")
		compression = splitChild.last
		splitChild.pop(2)
		dirName = splitChild.join(".")

		Dir.mkdir("#{$baseDir}/build/#{dirName}")
		Dir.chdir("#{$baseDir}/build/#{dirName}")

		case compression
			when "gz"
				system("gunzip -c #{$baseDir}/tarballs/#{i} | tar x --strip-components=1")
			when "bz2"
				system("bunzip2 -c #{$baseDir}/tarballs/#{i} | tar x --strip-components=1")
			when "xz"
				system("xz -dc #{$baseDir}/tarballs/#{i} | tar x --strip-components=1")
			when "zst"
				system("zstd -dc #{$baseDir}/tarballs/#{i} | tar x --strip-components=1")
			else
				puts "Error!"
				errorHandler("Unknown compression type", false)
				exit 1
		end

		puts "Done."
	end

	openDir.close
	Dir.chdir("#{$baseDir}")
end

# Applies patches in the patch directory for each package. Useful for adding
# changes to big projects (eg: LLVM).
#
# Args:
# - pkgList: string array
def patchPkgs pkgList
	for pkg in pkgList
		# check if patch folder exists
		if Dir.exist?("#{$baseDir}/pl-files/patches/#{pkg}") == false
			next
		end

		fileParse = PLML.load_file("#{$configDir}/pkg/#{pkg}.plml")

		print "Patching #{pkg}..."

		# check if package has already been patched
		if File.exist?("#{$baseDir}/build/#{fileParse["name"]}-#{fileParse["version"]}/.patched")
			puts "Skipped."
			next
		end
		Dir.chdir("#{$baseDir}/pl-files/patches/#{pkg}")

		# apply each patch
		for i in Dir.glob("**/*.patch")
			pfile = File.expand_path(i)
			Dir.chdir("#{$baseDir}/build/#{fileParse["name"]}-#{fileParse["version"]}")
			system("touch .patched")
			system("patch -sp1 -i #{pfile}")
			Dir.chdir("#{$baseDir}/pl-files/patches/#{pkg}")
		end

		puts "Done."
		Dir.chdir("#{$baseDir}")
	end
end

# Copies files in the overlay directory for each package. Useful for adding
# custom toybox applets.
#
# Args:
# - pkgList: string array
def overlayPkgs pkgList
	for pkg in pkgList
		# check if overlay exists
		if Dir.exist?("#{$baseDir}/pl-files/overlays/#{pkg}") == false
			next
		end

		fileParse = PLML.load_file("#{$configDir}/pkg/#{pkg}.plml")

		Dir.chdir("#{$baseDir}/build/#{fileParse["name"]}-#{fileParse["version"]}")
		openDir = Dir.open("#{$baseDir}/pl-files/overlays/#{pkg}")

		print "Applying overlay for #{pkg}..."

		for i in openDir.each_child
			system("cp -rf #{openDir.path}/#{i} ./")
		end

		puts "Done."
		Dir.chdir("#{$baseDir}")
	end
end

def init extraPkgs
	if Dir.exist?("#{$baseDir}/tarballs") == false
		Dir.mkdir("#{$baseDir}/tarballs")
	end
	if Dir.exist?("#{$baseDir}/build") == false
		Dir.mkdir("#{$baseDir}/build")
	end

	puts "Stage 1: Download packages"

	presetFile = PLML.load_file("#{$configDir}/#{$preset}.plml")
	list = presetFile["pkgList"]
	if extraPkgs != nil
		for file in extraPkgs
			list.push file
		end
	end

	fetchPkgs list

	puts "Stage 1 Complete! Starting Stage 2"
	puts "Stage 2: Extract packages"

	decompressPkgs

	puts "Stage 2 Complete! Starting Stage 3"
	puts "Stage 3: Patching and applying overlays"

	patchPkgs list
	overlayPkgs list

	puts "Stage 3 Complete! Starting Stage 4"
	puts "Stage 4: Create config file"

	if File.exist?("#{$baseDir}/.config") == true
		puts "Config file exists, skipping..."
	else
		print "Creating config file..."
		configFile = File.open("#{$baseDir}/.config", "w")

		configFile.write("preset = #{$preset}\n")
		configFile.write("prefix = #{$prefix}\n")
		configFile.write("arch = #{$arch}\n")
		configFile.write("toolchain = #{presetFile["toolchain"]}\n")
		configFile.write("tcprefix = #{$prefix}/#{presetFile["toolchain"]}\n")
		if extraPkgs != nil
			configFile.write("extrapkg: #{extraPkgs}")
		end
		configFile.close

		puts "Done."
	end

	puts "Stage 4 Complete!"
end

def parseArgs
	extraPkgs = nil
	args = ARGV

	while args.length > 0
		case args[0]
			when "-a"
				if args.length < 2
					errorHandler("Not enough arguments", true)
				end
				$arch = args[1]
				args.shift
			when "-p"
				if args.length < 2
					errorHandler("Not enough arguments", true)
				end
				$preset = args[1]
				args.shift
			when "-P"
				if args.length < 2
					errorHandler("Not enough arguments", true)
				end
				if extraPkgs == nil
					extraPkgs = Array.new
				end
				extraPkgs.push(args[1])
				args.shift
			when "-t"
				if args.length < 2
					errorHandler("Not enough arguments",true)
				end
				$prefix = File.expand_path(args[1])
				args.shift
			when "-h"
				puts "Usage: #{$0} [-p preset] {-a arch|-t toolchain_prefix}"
				puts " -a	Sets the target architecture"
				puts "		Valid options depend on the profile"
				puts " -p	Sets which preset to use"
				puts "		The list of valid options may change depending on the changes done to internal build files"
				puts " -P	Adds an extra package to configure for building"
				puts "		Custom packages can be added in pl-files/configure-files/pkg"
				puts " -t	Sets the cross toolchain install directory"
				puts "		Default: ~/cross"
				print " -h	Shows this help\n\n"
				puts "For more information, please go to https://github.com/portalinux-project"
				exit
			else
				errorHandler("Unknown option", true)
		end
		args.shift
	end
	return extraPkgs
end

def validateArgs
	if $preset == ""
		errorHandler("Preset not set", true)
	end

	if File.exist?("#{$configDir}/#{$preset}.yaml") == false
		errorHandler("Preset not found", false)
	else
		parsedFile = PLML.load_file("#{$configDir}/#{$preset}.plml")
		$supportedArches = parsedFile["supportedArch"]

		if $arch != nil
			i = 0
			while $supportedArches[i] != $arch and i < $supportedArches.length
				i = i + 1
			end

			if i == $supportedArches.length
				errorHandler("Unknown architecture", true)
			end
		else
			$arch = $supportedArches[0]
		end
	end
end

puts "PortaLinux Configure System v0.11"
print "(c) 2020-2024 CinnamonWolfy & raisinware, Under MPL 2.0\n\n"

if ARGV.length < 1
	errorHandler("Not enough arguments", true)
end

extraPkgs = parseArgs
validateArgs

puts "Build Preset: #{$preset}"
puts "Architecture: #{$arch}"
puts "Toolchain Install Directory: #{$prefix}"

init extraPkgs
