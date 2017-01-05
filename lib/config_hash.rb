require 'config_hash/processors'

class ConfigHash < Hash
  include ConfigHash::Enumerable

  def initialize(hash, **options)
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

    super(hash.default, &hash.default_proc)

    # recursively reconstruct this hash from the passed in hash.
    hash.each do |key, value|
      key = key.to_sym if key.is_a?(String)
      self[key] = construct(value)
    end

    self.freeze if @freeze
  end

  ## Hash Accessor Methods

  def [](key)
    key = key.to_sym if key.is_a? String
    if @raise_on_missing && !self.include?(key)
      raise KeyError.new("key not found: #{key}")
    end

    if @lazy_loading && @processors.any?
      @processed[key] ||= process(super(key))
    else
      super(key)
    end
  end

  def []=(key, value)
    key = key.to_sym if key.is_a? String
    super(key, value).tap { __build_accessor(key) }
  end

  ## Modified Enumeration Methods
  # these overrides use [] to ensure that all values are processed correctly
  # if appropriate.

  def values
    return super unless @lazy_loading && @processors.any?
    self.keys.map { |k| self[k] }
  end

  # use [] accessor to process values correctly for lazy loading
  def each
    return super unless @lazy_loading && @processors.any?
    self.keys.each { |k| yield k, self[k] }
  end

  def map
    return super unless @lazy_loading && @processors.any?
    self.keys.map { |k| yield k, self[k] }
  end

  def select
    return super unless @lazy_loading && @processors.any?
    selected = Hash[
      self.keys.select { |k| yield k, self[k] }.map { |k| [k, self[k]] }
    ]
    self.class.new(selected,
      freeze:           @freeze,
      processors:       @processors,
      lazy_loading:     @lazy_loading,
      raise_on_missing: @raise_on_missing,
    )
  end

  [:all?, :any?, :none?, :one?].each do |method|
    define_method(method) do
      return super unless @lazy_loading && @processors.any?
      self.keys.send(method) { |k| yield k, self[k] }
    end
  end

  ## misc. overrides

  def method_missing(method, *args)
    # if we're not freezing, we can allow assignment and expect nil results.
    if method =~ /^(.*)=$/ && args.length == 1
      return super(method, *args) if @freeze # will raise an error
      key = method.to_s.tr('=', '').to_sym
      self[key] = args[0]
      __build_accessor(key)

      self[key] # assignment should return the value
    else
      raise KeyError.new("key not found: #{method}!") if @raise_on_missing
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

  # returns the value as reduced by the processors.
  # only applies to scalars that are not class, module, proc, or method.
  #
  # @param [Mixed] value The value to process
  # @return [Mixed] the value, modified by calls to the processor.
  def process(value)
    case value
    when ConfigHash then value # the sub-config-hash will process on its own
    when Hash       then Hash[value.keys.map { |k| [k, process(value[k])] }]
    when Array      then value.map { |sv| process(sv) }
    when Class, Module, Proc, Method then value
    else @processors.reduce(value) { |modified, proc| proc.call(modified) }
    end
  end

  def construct(value)
    case value
      when ConfigHash                  then value
      when Hash                        then ConfigHash.new(
        value,
        freeze:           @freeze,
        processors:       @processors,
        lazy_loading:     @lazy_loading,
        raise_on_missing: @raise_on_missing,
      )
      when Array                       then value.map { |sv| construct(sv) }
      when Class, Module, Proc, Method then value
      else                                  (!@lazy_loading && @processors.any?) ? process(value) : value
    end.tap { |calced| calced.freeze if @freeze }
  end
end
