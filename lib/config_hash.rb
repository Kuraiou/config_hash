require 'config_hash/processors'

class ConfigHash < Hash
  def initialize(hash, default=nil, **options, &default_block)
    unless hash.kind_of?(Hash)
      raise ArgumentError.new("first argument must be a hash!")
    end

    @freeze     = options.fetch(:freeze, true)
    @processors = options.fetch(:processors, [])
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

      class << self; self; end.class_eval do
        define_method(key) { self[key] }
      end
    end

    self.freeze if @freeze
  end

  def method_missing(method, *args)
    return super(method, *args) if @freeze

    # if we're not freezing, we can allow assignment and expect nil results.
    if method =~ /^(.*)=$/ && args.length == 1
      key = method.to_s.tr('=', '').to_sym
      self[key] = args[0]

      class << self; self; end.class_eval do
        define_method(key) { self[key] }
      end
    end
  end

  def delete(key, &blk)
    return super(key, &blk) if @freeze

    key = key.is_a?(String) ? key.to_sym : key
    class << self; self; end.class_eval do
      remove_method(key)
    end

    super(key, &blk)
  end

  private

  def process(value)
    @processors.reduce(value) { |modified, proc| proc.call(modified) }
  end

  def construct(value)
    case value
      when ConfigHash                  then value
      when Hash                        then ConfigHash.new(
        value,
        value.default,
        freeze: @freeze, processors: @processors,
        &value.default_proc
      )
      when Array                       then value.map { |sv| construct(sv) }
      when Class, Module, Proc, Method then value
      else                                  @processors.any? ? process(value) : value
    end.tap { |calced| calced.freeze if @freeze }
  end
end
