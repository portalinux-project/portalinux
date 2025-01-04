#!/usr/bin/env ruby
# SPDX-License-Identifier: MPL-2.0

$LOAD_PATH.append(File.expand_path("./lib"))

require 'common-ports'
require 'etc'
require 'fileutils'

$rootDir = "#{File.dirname $0}"
$threads = Etc.nprocessors
$rootfsDir = "#{$rootDir}/rootfs"

def calculateTime startTime
	totalTime = Time.now.to_i - startTime
	hours = totalTime / (60 * 60)
	minutes = (totalTime - (hours * (60 * 60))) / 60
	seconds = (totalTime - (hours * (60 * 60)) - (minutes * 60))
	multipleFields = false

	if hours != 0
		print "#{hours} hour"
		if hours > 1
			print "s"
		end
		print ", "
		multipleFields = true
	end

	if minutes != 0
		print "#{minutes} minute"
		if minutes > 1
			print "s"
		end
		print " and "
		multipleFields = true
	end

	print "#{seconds} second"
	if seconds != 1
		print "s"
	end
	print "\n"
end

def fetchPackage(packageName)
	# TODO: implement package fetching
	if File.exist?("#{packageName}.popk") == false and Dir.exist?("#{packageName}") == false
		PLPorts::Common.errorHandler("Fetching is not implemented. You must give a package that exists within the current directory")
	end

	if Dir.exist?("#{packageName}") == false
		print "* Extracting #{packageName}..."
		extracted = PLPorts::Common.extractArchive("#{packageName}.popk", packageName)
		if extracted == 1
			puts "Skipped."
			Dir.chdir(packageName)
		else
			puts "Done."
		end
	end
end
