Gem::Specification.new do |spec|
  spec.name     = "plml"
  spec.summary  = "Ruby bindings to the pl-rt implementation of PLML"
  spec.version  = "0.01"
  spec.authors  = %w(CinnamonWolfy) 

  spec.required_ruby_version = "> 2.3"
  spec.files = `git ls-files`.split("\n")

  spec.extensions = %w(ext/plml/extconf.rb)
  spec.require_paths = %w(lib)
end
