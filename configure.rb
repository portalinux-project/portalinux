#!/usr/bin/env ruby
require 'yaml'
require 'net/http'

$validArchitectures = [ "i486", "i586", "i686", "x86_64", "armv5", "armv6", "armv6k", "armv7", "aarch64", "riscv64" ]

$arch = ""
$preset = ""
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

def parseArgs
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
			when "-t"
				if args.length < 2
					errorHandler("Not enough arguments",true)
				end
				$prefix = File.expand_path(args[1])
				args.shift
			when "-h"
				puts "Usage: #{$0} [-a arch|-p preset] {-t toolchain_prefix}"
				puts " -a	Sets the target architecture"
				puts "		Valid options:"
				puts "			i486"
				puts "			i586"
				puts "			i686"
				puts "			x86_64"
				puts "			armv5"
				puts "			armv6"
				puts "			armv6k"
				puts "			armv7"
				puts "			aarch64"
				puts "			riscv64"
				puts " -p	Sets which preset to use"
				puts "		The list of valid options may change depending on the changes done to internal build files"
				puts " -t	Sets the cross toolchain install directory"
				puts "		Default: ~/cross"
				print " -h	Shows this help\n\n"
				puts "For more information, please go to https://github.com/pocketlinux32/portalinux"
				exit				
			else
				errorHandler("Unknown option", true)
		end
		args.shift
	end
end

def validateArgs
	if $arch == ""
		errorHandler("Architecture not set", true)
	end

	if $preset == ""
		errorHandler("Preset not set", true)
	end

	i = 0
	while $validArchitectures[i] != $arch and i < $validArchitectures.length
		i = i + 1
	end

	if i == $validArchitechtures.length
		errorHandler("Unknown architecture", true)
	end

	if File.exist?("#{$configDir}/#{$preset}.yaml") == false
		errorHandler("Preset not found", false)
	end
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
	downloadedFile = File.open(file, "wb")
	downloadedFile.write(response.body)
	downloadedFile.close

	puts "Done."
end

def fetchPkgs pkgList
	for i in pkgList
		fileParse = YAML.load_file("#{$configDir}/pkg/#{i}.yaml")

		if fileParse["github"] == true
			tempUrl = "https://codeload.github.com/#{fileParse["url"]}/tar.gz/refs/"
			if fileParse["tag"] == nil
				tempUrl = tempUrl + "heads/"
				if fileParse["branch"] == nil
					tempUrl = tempUrl + "main"
				else
					tempUrl = tempUrl + fileParse["branch"]
				end
			else
				tempUrl = tempUrl + "tags/" + fileParse["tag"]
			end

			downloadFile(tempUrl, "#{$baseDir}/tarballs/#{fileParse["name"]}-#{fileParse["version"]}.tar.gz", true)
		else
			use_secure = false
			if fileParse["secure"] != nil
				use_secure = fileParse["secure"]
			end

			downloadFile(fileParse["url"], "#{$baseDir}/tarballs/#{File.basename(URI.parse(fileParse["url"]).path)}", use_secure)
		end		
	end
end

def decompressPkgs
	if Dir.empty?("#{$baseDir}/build") == false
		puts "Build directory is not empty. Skipping decompression stage..."
		return
	end

	Dir.chdir("#{$baseDir}/build")
	openDir = Dir.open("#{$baseDir}/tarballs")

	for i in openDir.each_child
		print "Decompressing #{i}..."
		
		compression = i.split(".").last
		case compression
			when "gz"
				system("gunzip -c #{$baseDir}/tarballs/#{i} | tar x")
			when "bz2"
				system("bunzip2 -c #{$baseDir}/tarballs/#{i} | tar x")
			when "xz"
				system("xz -dc #{$baseDir}/tarballs/#{i} | tar x")
			when "zst"
				system("zstd -dc #{$baseDir}/tarballs/#{i} | tar x")
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

def init
	if Dir.exist?("#{$baseDir}/tarballs") == false
		Dir.mkdir("#{$baseDir}/tarballs")
	end
	if Dir.exist?("#{$baseDir}/build") == false
		Dir.mkdir("#{$baseDir}/build")
	end

	puts "Stage 1: Download packages"
	
	presetFile = YAML.load_file("#{$configDir}/#{$preset}.yaml")
	list = presetFile["pkgList"].split(" ")

	fetchPkgs list

	puts "Stage 1 Complete! Starting Stage 2"
	puts "Stage 2: Extract packages"

	decompressPkgs

	puts "Stage 2 Complete! Starting Stage 3"
	puts "Stage 3: Create config file"

	if File.exist?(".config") == true
		puts "Config file exists, skipping..."
	else
		print "Creating config file..."
		configFile = File.open(".config", "w")

		configFile.write("arch: #{$arch}\n")
		configFile.write("toolchain: #{$preset}\n")
		configFile.write("tcprefix: #{$prefix}\n")
		configFile.close

		puts "Done."
	end	

	puts "Stage 3 Complete!"
end

puts "PortaLinux Configure System v0.11"
print "(c) 2022-2023 pocketlinux32 & raisinware, Under MPL 2.0\n\n"

if ARGV.length < 1
	errorHandler("Not enough arguments", true)
end

parseArgs
validateArgs

puts "Build Preset: #{$preset}"
puts "Architecture: #{$arch}"
puts "Toolchain Install Directory: #{$prefix}"

init
