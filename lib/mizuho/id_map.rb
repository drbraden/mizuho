require 'mizuho/fuzzystringmatch'

module Mizuho

class IdMap
	URANDOM = File.open("/dev/urandom", "rb")
	MATCHER = JaroWinklerPure.new
	
	def initialize(filename)
		@entries  = {}
		@fuzzy    = 0
		@orphaned = 0
		#@namespace    = slug(File.basename(filename, File.extname(filename)))
	end
	
	def load(filename)
		@entries.clear
		@fuzzy    = 0
		@orphaned = 0
		File.open(filename, "r") do |f|
			fuzzy = false
			while !f.eof?
				line = f.readline.strip
				if line.empty?
					fuzzy = false
				elsif line == "# fuzzy"
					fuzzy = true
				elsif line !~ /\A#/
					content, id = line.split("\t=>\t", 2)
					entry = Entry.new(content, id, fuzzy, false)
					@entries[content] = entry
					@fuzzy += 1 if fuzzy
					@orphaned += 1
					fuzzy = false
				end
			end
		end
		return self
	end
	
	def save(filename)
		normal = []
		orphaned = []
		
		@entries.each_value do |entry|
			if entry.associated?
				normal << entry
			else
				orphaned << entry
			end
		end
		
		if orphaned.size != @orphaned
			raise "BUG: orphaned count is incorrect (should be #{orphaned.size} but got #{@orphaned})"
		end
		
		normal.sort!
		orphaned.sort!
		
		File.open(filename, "w") do |f|
			f.puts '###### Autogenerated by Mizuho, DO NOT EDIT ######'
			f.puts '# This file maps section names to IDs so that the commenting system knows which'
			f.puts '# comments belong to which section. Section names may be changed at will but'
			f.puts '# IDs always stay the same, allowing one to retain old comments even if you'
			f.puts '# rename a section.'
			f.puts '#'
			f.puts '# This file is autogenerated but is not a cache; you MUST NOT DELETE this'
			f.puts '# file and you must check it into your version control system. If you lose'
			f.puts '# this file you may lose the ability to identity old comments.'
			f.puts '#'
			f.puts '# Entries marked with "fuzzy" indicate that the section title has changed'
			f.puts '# and that Mizuho has found an ID which appears to be associated with that'
			f.puts '# section. You should check whether it is correct, and if not, fix it.'
			f.puts
			
			fuzzy = 0
			normal.each do |entry|
				if entry.fuzzy?
					f.puts "# fuzzy"
					fuzzy += 1
				end
				f.puts "#{entry.content}	=>	#{entry.id}"
				f.puts
			end
			if !orphaned.empty?
				f.puts
				f.puts "### These sections appear to have been removed. Please check."
				f.puts
				orphaned.each do |entry|
					f.puts "# orphaned"
					f.puts "#{entry.content}	=>	#{entry.id}"
					f.puts
				end
			end
			
			if fuzzy != @fuzzy
				raise "BUG: fuzzy count is incorrect (should be #{fuzzy} but got #{@fuzzy})"
			end
		end
	end
	
	def fuzzy_count
		return @fuzzy
	end
	
	def orphaned_count
		return @orphaned
	end
	
	def associate(title)
		if entry = @entries[title]
			if entry.associated?
				raise "Duplicate title detected, this should never happen"
			else
				entry.associated = true
				id = entry.id
				@orphaned -= 1
			end
		elsif entry = find_similar(title)
			@entries.delete(entry.content)
			@entries[title] = entry
			entry.content = title
			entry.associated = true
			entry.fuzzy = true
			id = entry.id
			@orphaned -= 1
			@fuzzy += 1
		else
			id = create_unique_id(title)
			@entries[title] = Entry.new(title, id, false, true)
		end
		return id
	end

private
	class Entry < Struct.new(:content, :id, :fuzzy, :associated)
		alias fuzzy? fuzzy
		alias associated? associated
		
		def <=>(other)
			return content <=> other.content
		end
	end
	
	def find_similar(title)
		lower_title = title.downcase
		best_score = nil
		best_match = nil
		@entries.each_value do |entry|
			next if entry.associated?
			score = MATCHER.getDistance(entry.content.downcase, lower_title)
			if best_score.nil? || score > best_score
				best_score = score
				best_match = entry
			end
		end
		if best_score && best_score > 0.8
			return best_match
		else
			return nil
		end
	end
	
	def slug(text)
		text = text.downcase
		text.gsub!(/^(\d+\.)+ /, '')
		text.gsub!(/[^a-z0-9\-\_]/i, '-')
		text.gsub!('_', '-')
		text.gsub!(/--+/, '-')
		return text
	end
	
	def create_unique_id(title)
		suffix = URANDOM.read(4).unpack('H*')[0].to_i(16).to_s(36)
		return "#{slug(title)}-#{suffix}"
	end
end

end