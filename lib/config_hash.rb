require 'config_hash/processors'

class ConfigHash < Hash
  def initialize(hash, default=nil, **options, &default_block)
    unless hash.kind_of?(Hash)
      raise ArgumentError.new("first argument must be a hash!")
    end

    @freeze           = options.fetch(:freeze, true)
    @lazy_loading     = options.fetch(:lazy_loading, false)
    @processors       = options.fetch(:processors, [])
    @raise_on_missing = options.fetch(:raise_on_missing, true)
    @processed        = {}

    if !(@processors.is_a?(Array) && @processors.all? { |p| p.is_a?(Proc) || p.is_a?(Method) })
      raise ArgumentError.new("processors must be a list of callables!")
    end
    # allow default processors to be assigned by those method names specially.
    ConfigHash::Processors.methods(false).each do |proc|
      @processors << ConfigHash::Processors.method(proc) if options[proc]
    end

    # recursively reconstruct this hash from the passed in hash.
    hash.each do |key, value|
      key = key.to_sym if key.is_a?(String)
      self[key] = construct(value)
    end

    self.freeze if @freeze
  end

  def [](key)
    key = key.to_sym if key.is_a? String
    if @raise_on_missing && !self.include?(key)
      raise ArgumentError.new("Missing Key #{key} in #{self.keys}!")
    end

    if @lazy_loading
      @processed[key] ||= process(super(key))
    else
      super(key)
    end
  end

  def []=(key, value)
    return super(key, value) if self.frozen? # will raise an error.

    key = key.to_sym if key.is_a? String
    super(key, value).tap { __build_accessor(key) }
  end

  def method_missing(method, *args)
    # if we're not freezing, we can allow assignment and expect nil results.
    if method =~ /^(.*)=$/ && args.length == 1
      return super(method, *args) if @freeze # will raise an error
      key = method.to_s.tr('=', '').to_sym
      self[key] = args[0]
      __build_accessor(key)

      self[key] # assignment should return the value
    else
      raise ArgumentError.new("Missing Key #{method}!") if @raise_on_missing
      nil
    end
  end

  def delete(key, &blk)
    return super(key, &blk) if self.frozen?

    key = key.is_a?(String) ? key.to_sym : key
    class << self; self; end.class_eval do
      remove_method(key)
    end

    super(key, &blk)
  end

  private

  def __build_accessor(key)
    return unless key.is_a?(Symbol) && key !~ /^\d/

    class << self; self; end.class_eval do
      define_method(key) { self[key] }
    end
  end

  def process(value)
    @processors.reduce(value) { |modified, proc| proc.call(modified) }
  end

  def construct(value)
    case value
      when ConfigHash                  then value
      when Hash                        then ConfigHash.new(
        value,
        value.default,
        freeze:           @freeze,
        processors:       @processors,
        lazy_loading:     @lazy_loading,
        raise_on_missing: @raise_on_missing,
        &value.default_proc
      )
      when Array                       then value.map { |sv| construct(sv) }
      when Class, Module, Proc, Method then value
      else                                  (!@lazy_loading && @processors.any?) ? process(value) : value
    end.tap { |calced| calced.freeze if @freeze }
  end
end
