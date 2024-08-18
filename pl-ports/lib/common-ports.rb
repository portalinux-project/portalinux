# SPDX-License-Identifier: MPL-2.0
# Common code for PortaLinux Ports System and PortaLinux Build System, v0.01
# (c)2024 CinnamonWolfy, Under MPL 2.0

require 'yaml'
# require_relative 'plml.rb' # Not implemented yet
require 'net/http'

module PLPorts
	module Common
		def self.errorHandler(msg)
			puts "Error: #{msg}"
			exit 1
		end

		def self.blockSpawn(execString, envVars=nil)
			pid = -1
			if envVars.class == Hash
				pid = spawn(envVars, execString)
			else
				pid = spawn(execString)
			end
			Process.wait pid
			if $?.exitstatus != 0
				errorHandler("Program exited with nonzero code #{$?.exitstatus}")
			end
		end

		def self.shellRun(shellCommand)
			success = system(shellCommand)
			if success == false
				errorHandler("Program exited with nonzero code #{$?.exitstatus}")
			end
		end

		def self.downloadFile(url, file, secure)
			if File.exist?(file) == true
				return 1
			end

			uri = URI(url)
			port = 80
			if secure == true
				port = 443
			end

			connection = Net::HTTP.new(uri.host, port)
			connection.use_ssl = secure
			response = connection.get(uri.path)
			if response.code.to_i >= 400
				puts "Error!"
				errorHandler(response.body)
			end
			downloadedFile = File.open(file, "wb")
			downloadedFile.write(response.body)
			downloadedFile.close

			return 0
		end
	
		def self.extractArchive(filename, decompressPath)
			if Dir.exist?("#{decompressPath}") == true
				return 1
			end

			splitFile = filename.split(".")
			compression = splitFile.last
			splitFile.pop(2)

			fileParentDir = File.expand_path("#{File.dirname filename}")

			Dir.mkdir("#{decompressPath}")
			Dir.chdir("#{decompressPath}")

			case compression
				when "gz"
					shellRun("gunzip -c #{fileParentDir}/#{filename} | tar x --strip-components=1")
				when "bz2"
					shellRun("bunzip2 -c #{fileParentDir}/#{filename} | tar x --strip-components=1")
				when "xz"
					shellRun("xz -dc #{fileParentDir}/#{filename} | tar x --strip-components=1")
				when "zst"
					shellRun("zstd -dc #{fileParentDir}/#{filename} | tar x --strip-components=1")
				when "popk"
					shellRun("zcat #{fileParentDir}/#{filename} | tar x --strip-components=1")
				else
					puts "Error!"
					errorHandler("Unknown compression type")
			end

			return 0
		end

		def self.patchAndOverlay(patchDir, overlayDir, buildDir)
			print "* Patching sources..."

			# check if package has patches or has already been patched
			if Dir.exist?(patchDir) == false or File.exist?("#{buildDir}/.patched")
				puts "Skipped."
			else
				Dir.chdir("#{patchDir}")

				# apply each patch
				for i in Dir.glob("*.patch")
					pfile = File.expand_path(i)
					Dir.chdir("#{buildDir}")
					shellRun("touch .patched")
					shellRun("patch -sp1 -i #{pfile}")
					Dir.chdir("#{patchDir}")
				end
				puts "Done."
			end

			print "* Applying overlay to sources..."

			# check if overlay exists
			if Dir.exist?("#{overlayDir}") == false
				puts "Skipped."
			else
				Dir.chdir("#{buildDir}")
				FileUtils.cp_r(Dir.glob("#{overlayDir}/*"), ".")
				puts "Done."
			end
		end
	end

	module BasePackage
		extend self

		def init(buildDir = './src', patchDir = './patches', overlayDir = './overlay')
			pkgInfo = YAML.load_file('./properties.yaml')
			if pkgInfo == nil
				Common.errorHandler("Invalid properties.yaml")
			end

			@pkgName = pkgInfo['name']
			@pkgVersion = pkgInfo['version']
			@pkgAuthor = pkgInfo['author']
			@pkgUrl = pkgInfo['url']
			@pkgConfigFlags = pkgInfo['configure-flags']
			@pkgCompileFlags = pkgInfo['compile-flags']
			@pkgBuildDir = File.expand_path(buildDir)
			@pkgPatchDir = File.expand_path(patchDir)
			@pkgOverlayDir = File.expand_path(overlayDir)

			if @pkgName == nil or @pkgVersion == nil or @pkgUrl == nil
				Common.errorHandler("Invalid properties.yaml")
			end
		end

		def fetch()
			print "* Downloading sources..."
			filename = "#{File.basename @pkgUrl}"
			secure = false
			if @pkgUrl.match?("https") == true or @pkgUrl.match?("github.com")
				secure = true
				if @pkgUrl.match?("github.com")
					filename = "#{@pkgName}-#{@pkgVersion}.tar.gz"
				end
			end

			completion = Common.downloadFile(@pkgUrl, filename, secure)
			if completion == 1
				puts "Skipped."
			else
				puts "Done."
			end

			print "* Extracting sources..."
			completion = Common.extractArchive(filename, @pkgBuildDir)
			if completion == 1
				puts "Skipped."
			else
				puts "Done."
			end

			Common.patchAndOverlay(@pkgPatchDir, @pkgOverlayDir, @pkgBuildDir)

			Dir.chdir(@pkgBuildDir)
		end
	end
end
