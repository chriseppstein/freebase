module Freebase::Api
  # A class for returing errors from the freebase api.
  # For more infomation see the freebase documentation:
  # http://www.freebase.com/view/help/guid/9202a8c04000641f800000000544e139#mqlreaderrors
  class MqlReadError < ArgumentError
    attr_accessor :code, :freebase_message
    def initialize(code,message)
      self.code = code
      self.freebase_message = message
    end
    def message
      "#{code}: #{freebase_message}"
    end
  end
  
  # Encapsulates a Freebase result, enables method-based access to the returned values.
  # E.g.
  # result = mqlread(:type => "/music/artist", :name => "The Police", :id => nil)
  # result.id => "/topic/en/the_police"
  class FreebaseResult
    
    attr_accessor :result
    
    def initialize(result)
      @result = result.symbolize_keys!
    end
    
    def id
      @result[:id]
    end
    
    # result.type is reserved in ruby. Call result.fb_type to access :type instead.
    def fb_type
      @result[:type]
    end
    
    # returns the first element of an array if it is one
    # this for handling generic mql queries like [{}] that return only a single value
    def depluralize(v)
      Array(v).first
    end
    
    # converts a returned value from freebase into the corresponding ruby object
    # This is done first by the core data type and then by the type attribute for an object
    # The casing is done using a method dispatch pattern which
    # should make it easy to mix-in new behaviors and type support
    def resultify(v)
      resultify_method = "resultify_#{v.class.to_s.downcase}".to_sym
      v = send(resultify_method, v) if respond_to? resultify_method
      return v
    end
    
    # resultifies each value in the array
    def resultify_array(v)
      v.map{|vv| resultify(vv)}
    end
    
    # resultifies an object hash
    def resultify_hash(v)
      vtype = indifferent_access(v,:type)
      if value_type? vtype
        resultify_value(vtype,v)
      elsif vtype.blank?
        Logger.debug "What's This: #{v.inspect}"
        FreebaseResult.new(v)
      elsif vtype.is_a? Array
        "Freebase::Types#{vtype.first.classify}".constantize.new(v) #TODO: Union these types
      else
        "Freebase::Types#{vtype.classify}".constantize.new(v)
      end
    end
    
    #decides if a type is just an expanded simple value object
    def value_type?(t)
      ['/type/text', '/type/datetime'].include?(t)
    end
    
    # dispatches to a value method for the type
    # or returns the simple value if it doesn't exist
    # for example /type/text would dispatch to resultify_value_type_text
    def resultify_value(vtype,v)
      resultify_method = "resultify_value#{vtype.gsub(/\//,'_')}".to_sym
      if respond_to? resultify_method
        send(resultify_method, v) 
      else
        indifferent_access(v,:value)
      end
    end
    
    #provides method based access to the result properties
    def method_missing(name, *args)
      raise NoMethodError.new(name.to_s) unless args.length == 0
      if @result.has_key?(name)
        resultify @result[name]
      elsif @result.has_key?((singularized_name = name.to_s.singularize.to_sym)) and @result[singularized_name].is_a?(Array)
        resultify @result[singularized_name]
      else
        raise NoMethodError.new(name.to_s)
      end
    end
    
    protected
      def indifferent_access(h,k)
         h[k] || h[k.to_s] if (h.has_key?(k) || h.has_key?(k.to_s))
      end

  end
  
  # the configuration class controls access to the freebase.yml configuration file.
  # it will load the rails-environment specific configuration
  class Configuration
    
    include Singleton
    
    attr_accessor :filename
    
    DEFAULTS = {:host => 'sandbox.freebase.com', :debug => true, :trace => false}
    
    def initialize
      @configuration = {}.reverse_merge!(DEFAULTS)
      configure_rails if defined?(RAILS_ROOT)
    end
    
    def configure_rails
      @filename = "#{RAILS_ROOT}/config/freebase.yml"
      unless File.exists? @filename
        puts "WARNING: #{RAILS_ROOT}/config/freebase.yml configuration file is not found. Using sandbox.freebase.com." 
      else
        set_all YAML.load_file(@filename)[RAILS_ENV].symbolize_keys!
      end
    end
    
    def set_all(opts = {})
      opts.each {|k,v| self[k] = v}
    end
    
    def []=(k,v)
      @configuration[k] = v
    end
    
    def [](k)
      @configuration[k]
    end
  end
  
  # logging service. Is it a bad idea?
  class Logger
    #TODO: log4r or rails logging?
    [:trace, :debug, :warn, :error].each do |level|
      eval %Q{
        def self.#{level}(message = nil)
          if Configuration.instance[:#{level}]
            puts message || yield
          end
        end
      }        
    end
  end
  
  SERVICES = { :mqlread => '/api/service/mqlread',
    :mqlwrite => '/api/service/mqlwrite',
    :login => '/api/account/login',
    :upload => '/api/service/upload'
  }
  
  # get the service url for the specified service.
  def service_url(svc)
    "http://#{Configuration.instance[:host]}#{SERVICES[svc]}"
  end
  
  SERVICES.each_key do |k|
    define_method("#{k}_service_url") do
      service_url(k)
    end
  end
  
  # raise an error if the inner response envelope is encoded as an error
  def handle_read_error(inner)
    unless inner['code'].starts_with?('/api/status/ok')
      Logger.error "<<< Received Error: #{inner.inspect}"
      error = inner['messages'][0]
      raise MqlReadError.new(error['code'], error['message'])
    end
  end
  

  
  # perform a mqlread and return the results
  # Specify :raw => true if you don't want the results converted into a FreebaseResult object.
  def mqlread(query, options = {})
    Logger.trace {">>> Sending Query: #{query.inspect}"}
    envelope = { :qname => {:query => query }}
    response = http_request mqlread_service_url, :queries => envelope.to_json
    result = ActiveSupport::JSON.decode(response)
    inner = result['qname']
    handle_read_error(inner)
    Logger.trace {"<<< Received Response: #{inner['result'].inspect}"}
    if options[:raw]
      inner['result']
    else
      inner['result'] ? FreebaseResult.new(inner['result']) : nil
    end
  end
  
  protected
  def params_to_string(parameters)
    parameters.keys.map {|k| "#{URI.encode(k.to_s)}=#{URI.encode(parameters[k])}" }.join('&')
  end
  def http_request(url, parameters = {})
    params = params_to_string(parameters)
    url << '?'+params unless params.blank?
    returning(Net::HTTP.get_response(URI.parse(url)).body) do |response|
      Logger.trace do
        fname = "#{MD5.md5(params)}.mql"
        open(fname,"w") do |f|
          f << response
        end
        "Wrote response to #{fname}"
      end
    end
  end
end