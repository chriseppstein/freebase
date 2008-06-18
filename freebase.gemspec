# require 'rake'
# require 'rubygems'

FREEBASE_GEMSPEC = Gem::Specification.new do |s| 
  s.name = "freebase"
  s.version = "0.0.1"
  s.author = "Chris Eppstein"
  s.email = "chris@eppsteins.net"
  s.homepage = "http://rubyforge.org/projects/freebaseapi/"
  s.rubyforge_project = "freebaseapi"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby wrapper for the Freebase.com API that makes interacting with freebase.com in your Ruby on Rails application as easy as using Active Record. Freebase is a free, collaborative semantic database."
  # s.files = FileList["{bin,lib}/**/*"].to_a
  s.files = ["lib/core_extensions.rb", "lib/freebase", "lib/freebase/api.rb", "lib/freebase.rb"]
  s.require_path = "lib"
  s.autorequire = "freebase"
  # s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.test_files = ["test/freebase_test.rb"]
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_dependency("activesupport", ">= 1.2.5")
  s.add_dependency("json", ">= 1.1.2")
end
