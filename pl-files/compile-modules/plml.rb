# SPDX-License-Identifier: MPL-2.0
# PLML implementation in Ruby by pocketlinux32/CinnamonWolfy

module PLML
	def tokenize(string)
		quotePos = [ string.index("\""), string.index("'") ]
	end

	def parse(string)
		tokenizedStr = tokenize(string)
	end

	def self.load_file(filename)
		file = File.open(filename)
		returnVal = Hash.new

		while file.tell != file.size
			returnVal.merge!(parse(file.readline))
		end

		return returnVal
	end
end

