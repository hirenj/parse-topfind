#!/usr/bin/ruby

if ARGV.length == 1
	dumpfile = ARGV.shift
else
	puts("\033[31mhow to:\033[0m ruby parse.rb mysql.dump\n")
	exit 1
end

STDOUT.sync = true

if File.exist?(dumpfile)
	d = File.new(dumpfile, "r")
	outfile = false
	table = ""
	directory = File.basename(dumpfile).gsub(/[^0-9a-z\.\_]/i, '')+'.tables'
	Dir.mkdir(directory) unless File.directory?(directory)
	while (line = d.gets)
		if line =~ /^-- Table structure for table .(.+)./
			table = $1.gsub(/[^0-9a-z\.\_]/i, '')
			puts("\033[32mfound\033[0m #{table}\n")
			outfile = File.new("#{directory}/#{table}.sql", "w")
		end
		if table != "" && outfile
			outfile.syswrite line
		end
	end
end