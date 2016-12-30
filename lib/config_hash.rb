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

    super(default, &default_block)

    # recursively construct this hash from the passed in hash.
    hash.each do |key, value|
      key = key.is_a?(String) ? key.to_sym : key # force strings to symbols
      self[construct(key)] = construct(value)

      if key.is_a? Symbol # allow '.' notation for symbol keys.
        self.instance_eval("def #{key}; process(self[:#{key}]); end")
      end
    end

    self.freeze if @freeze
  end

  def [](key, in_process=false)
    key = key.is_a?(String) ? key.to_sym : key
    return super(key) if in_process

    process(self.send(:[], key, true)) # make sure to process reutrn values
  end

  def method_missing(method, *args)
    return super(method, *args) if @freeze

    # if we're not freezing, we can allow assignment and expect nil results.
    if method =~ /^(.*)=$/ && args.length == 1
      key = method.to_s.tr('=', '').to_sym
      self[key] = args[0]
      self.instance_eval("def #{key}; process(self[:#{key}]); end")
    else
      nil # it's a non-defined value.
    end
  end

  def delete(key, &blk)
    return super(key, &blk) if @freeze

    key = key.is_a?(String) ? key.to_sym : key
    instance_eval("undef #{key}") if respond_to?(key)
    super(key, &blk)
  end

  private

  def process(value)
    @processors.reduce(value) { |modified, proc| proc.call(modified) }
  end

  def construct(value)
    case value
      when ConfigHash then value
      when Hash       then ConfigHash.new(
        value,
        value.default,
        freeze: @freeze, processors: @processors,
        &value.default_proc
      )
      when Array      then dup_if_appropriate(value).map { |sv| construct(sv) }
      else                 dup_if_appropriate(value)
    end.tap { |calced| calced.freeze if @freeze }
  end

  def dup_if_appropriate(v)
    # if it is a class, module, or proc, DO NOT DUP
    return v if [Class, Module, Proc].any? { |kls| v.instance_of?(kls) }
    v.dup rescue v # on symbol, integer just return value
  end
end
