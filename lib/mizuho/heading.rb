module Mizuho

class Heading
	attr_accessor :title
	attr_accessor :level
	attr_accessor :anchor
	attr_accessor :parent
	attr_accessor :children
	
	def initialize
		@children = []
	end
	
	def find_parent_with_level(level)
		h = self
		while h && h.level != level
			h = h.parent
		end
		return h
	end
	
	def title_without_numbers
		return title.sub(/^(\d+\.)+ /, '')
	end
end

end