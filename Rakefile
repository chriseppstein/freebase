require 'rake'
require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/rdoctask'

spec = Gem::Specification.new do |s| 
  s.name = "freebase"
  s.version = "0.0.1"
  s.author = "Chris Eppstein"
  s.email = "chris@eppsteins.net"
  s.homepage = "http://rubyforge.org/projects/freebaseapi/"
  s.rubyforge_project = "freebaseapi"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby wrapper for the Freebase.com API that makes interacting with freebase.com in your Ruby on Rails application as easy as using Active Record. Freebase is a free, collaborative semantic database."
  s.files = FileList["{bin,lib}/**/*"].to_a
  s.require_path = "lib"
  s.autorequire = "freebase"
  s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_dependency("activesupport", ">= 2.0.2")
  s.add_dependency("json", ">= 1.1.2")
end
 
Rake::GemPackageTask.new(spec) do |pkg| 
  pkg.need_tar = true 
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the freebase plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the freebase plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Freebase'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
