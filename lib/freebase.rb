# (c) Copyright 2007 Chris Eppstein. All Rights Reserved.

require 'rubygems'
require 'activesupport'
require 'net/http'
require 'core_extensions'

module Freebase
end

require 'freebase/api'

module Freebase
  # This module is a namespace scope for the Freebase domains
  module Types
    # Automagically creates modules for domains and classes for types
    # for matching namespaces to Freebase's domain/type naming structure.
    # Shouldn't need to be called manually because this is called by the module
    # whenever the constant is missing.
    def new_freebase_type(name)
      Freebase::Api::Logger.trace {"new freebase module = #{name}"}
      self.const_set(name, Module.new do
        def new_freebase_type(name)
          Freebase::Api::Logger.trace {"new freebase class = #{name}"}
          klass = self.const_set(name, Class.new(Freebase::Base))
          klass.class_eval do
            cattr_accessor :properties, :schema_loaded
          end
          returning(klass) do |tc|
            tc.load_schema! unless tc.schema_loaded?
            Freebase::Api::Logger.trace { "Attempting Mixin include: #{tc.name.sub(/Types/,"Mixins")}" }
            begin
              tc.send(:include, tc.name.sub(/Types/,"Mixins").constantize)
            rescue NameError => e
              Freebase::Api::Logger.trace "failed: #{e}"
            end
          end
        end

        module_function :new_freebase_type
      end)
    end

    module_function :new_freebase_type
  end
  
  # Add a module within this module that corresponds to a freebase class within Freebase::Types
  # and the methods will be mixed in automatically. E.g.:
  #   module Freebase::Mixins::Music
  #     module Track
  #       def formatted_length
  #         "#{self.length.to_i / 60}:#{sprintf("%02i", self.length.to_i % 60)}"
  #       end
  #     end
  #   end
  #
  # Will be mixed in to the Freebase::Types:Music:Track class
  module Mixins
  end
  
  # This is the base class for all dynamically defined Freebase Types.
  class Base < Api::FreebaseResult
    extend Api
    alias_method :attributes, :result
    def self.schema_loaded?
      self.schema_loaded || false
    end
    def self.freebase_type
      @freebase_type ||= self.name["Freebase::Types".length..self.name.length].underscore
    end
    def self.load_schema!
      self.properties = {}
      propobjs = mqlread(:type => '/type/type', :id => self.freebase_type, :properties => [{:name => nil, :id => nil, :type => nil, :expected_type => nil}]).properties
      propobjs.each {|propobj|
        self.properties[propobj.id.split(/\//).last.to_sym] = propobj
      }
      self.schema_loaded = true
    end
    def self.find(*args)
      options = args.extract_options!
      case args.first
      when :first
        raise ArgumentError.new("Too many arguments for find(:first)") if args.size > 1
        find_first(options)
      when :all
        raise ArgumentError.new("Too many arguments for find(:all)") if args.size > 1
        find_all(options)
      end
    end
    def self.add_required_query_attributes(conditions)
      case conditions
      when Array
        conditions.map! {|c| add_required_query_attributes(c)}
      when Hash
        if conditions.delete(:fb_object)
          conditions.reverse_merge!(:type => [], :id => nil) unless conditions.has_key?(:*)
        else
          conditions.reverse_merge!(:type => nil) unless conditions.has_key?(:*)
        end
        conditions.each {|k,v| add_required_query_attributes(v) unless k == :*}
      else
        conditions
      end
    end
    # Don't to call this directly. find(:first, options) will be dispatched here.
    # This method is provided for extensibility
    def self.find_first(options = {})
      conditions = options.fetch(:conditions, {}).reverse_merge(:type => self.freebase_type, :name=>nil, :* => [{}], :limit => 1)
      add_required_query_attributes(conditions)
      self.new(mqlread(conditions, :raw => true))
    end
    
    # Don't to call this directly. find(:all, options) will be dispatched here.
    # This method is provided for extensibility
    def self.find_all(options = {})
      query = options.fetch(:conditions, {}).merge(:type => self.freebase_type, :name=>nil, :* => [{}])
      query[:limit] = options[:limit] if options[:limit]
      add_required_query_attributes(query)
      mqlread([query], :raw => true).map{|i| self.new(i)}
    end
    
    # ActiveRecord:Base-like to_s for the class
    def self.to_s
      if respond_to?(:properties)  && !self.properties.blank?
        %Q{#<#{name} #{self.properties.map{|k,v| "#{k}:#{v.expected_type}"}.join(", ")}>}
      else
        "#<#{name}>"
      end
    end
    
    # (re)load all properties of this object
    def reload
      query = {:id => self.id, :type=>self.class.freebase_type, :name=> nil, :limit => 1}
      self.class.properties.each do |k,v|
        query[k] = [{}] unless query.has_key?(k)
      end
      @result = self.class.mqlread(query, :raw => true).symbolize_keys!
      Freebase::Api::Logger.trace { @result.inspect }
      return self
    end
    
    # access the properties of this object, lazy loading associations as required.
    def method_missing(name,*args)
      if self.class.properties.has_key?(name)
        reload unless attributes.has_key?(name)
        resultify attributes[name]
      elsif self.class.properties.has_key?((singularized_name = name.to_s.singularize.to_sym))
        reload unless attributes.has_key?(singularized_name)
        resultify attributes[singularized_name]
      else
        super
      end
    end
    
    # If the object has a name, return it, otherwise the id.
    def to_s
      respond_to?(:name) ? name : id
    end
  end
end