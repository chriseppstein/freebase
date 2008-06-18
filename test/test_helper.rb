require 'test/unit'
require 'md5'

rails_env = File.expand_path(File.join(File.dirname(__FILE__), '../../../../config/environment.rb'))
if File.exist? rails_env
  require rails_env
  require 'active_record/fixtures'
  require 'active_support/core_ext/module/aliasing'
else
  require 'rubygems'
  $:.unshift(File.dirname(__FILE__) + '/../lib')
  RAILS_ROOT = File.dirname(__FILE__)
  require 'active_record'
  require 'active_support/core_ext/module/aliasing'
  #require 'active_record/fixtures'
  require init_file if File.exist?(init_file = "#{File.dirname(__FILE__)}/../init")
  ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
end

require File.dirname(__FILE__)+'/../lib/freebase'

module Freebase::Api
  mattr_accessor :quiesced
  @@quiesced = []
  def http_request_with_test_support(query, parameters = {})
    raise ArgumentError.new("This object is Quiesced. Cannot call http_request: #{parameters.inspect}") if Freebase::Api.quiesced.include?(:all)
    fname = "#{File.dirname(__FILE__)}/fixtures/responses/#{MD5.md5(params_to_string(parameters))}.mql"
    unless File.exists?(fname)
      open(fname, "w") do |file|
        puts "WARNING: Couldn't find response file. Creating #{fname}"
        file << http_request_without_test_support(query, parameters)
      end
    end
    open(fname,"r").read
  end
  alias_method_chain :http_request, :test_support
end

class Freebase::Base < Freebase::Api::FreebaseResult
  class << self
    def find_with_quiesce(*args)
      raise ArgumentError.new("This object is Quiesced. Cannot call find: #{args.inspect}") if Freebase::Api.quiesced.include?(:find)
      find_without_quiesce(*args)
    end
    alias_method_chain :find, :quiesce
  end
  
  def reload_with_quiesce(*args)
    raise ArgumentError.new("This object is Quiesced. Cannot call reload: #{args.inspect}") if Freebase::Api.quiesced.include?(:reload)
    reload_without_quiesce(*args)
  end
  alias_method_chain :reload, :quiesce
end

class Test::Unit::TestCase
  def quiesce(*types)
    types << :all if types.blank?
    orig_quiesced = Freebase::Api.quiesced.dup
    Freebase::Api.quiesced += types
    begin
      yield
    ensure
      Freebase::Api.quiesced = orig_quiesced
    end
  end
end