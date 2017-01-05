# config_hash

A hash that is nice to use for configurations. It takes an existing hash in at
construction time, and by default returns a Hash that:

1. freezes all values recursively throughout the entire config
    * can be overridden with "freeze: false"
2. ensures indifferent access to keys (`'foo'` and `:foo` are the same key)
3. sets up '.' accessors for all values (given `{foo: :bar}`, can use `config.foo`)

This is done singularly at construction time. If you want, you can also assign
processors via the `:processors` initialization argument, which will modify the
value returned (both with `.` and `[]`) via methods at access time.

# Usage

```ruby
# standard accessors
config = ConfigHash.new({foo: :bar})
config.foo # :bar
config['foo'] # :bar
config[:foo] # :bar
config.x # raises an error!

# with special prcoessors

# constantize special processor
class SomeClass; end
config = ConfigHash.new({klass_reference: '::SomeClass'}, constantize: true)
config.klass_reference # SomeClass (the class itself0, NOT '::SomeClass'

# sometimes, you want to post-process instead of pre-process. this slows down the
# config hash, but may be necessary, e:g:

config = ConfigHash.new({klass_reference: '::DefinedLaterClass'}, constantize: true, lazy_loading: true)
# config.klass_reference -- would at this point return the string, as DefinedLaterClass
# does not exist.
class DefinedLaterClass; end
config.klass_reference # now returns the class DefinedLaterClass

# custom processor
module Singleton
  def self.processor(value)
    value.is_a?(String) ? value + ' world' : value
  end
end
config = ConfigHash.new({foo: [{bar: 'hello'}]}, processors: [Singleton.method(:processor)])
config.foo # [{bar: 'hello'}]
config.foo[0].bar # 'hello world'

# by default, missing values raise an error:
config = ConfigHash.new({foo: :bar})
config.baz # raises an error!
config[:baz] # raises an error!

# if you want to have it return nil like a typical hash, pass raise_on_missing: false
config = ConfigHash.new({foo: :bar}, raise_on_missing: false)
config.baz # nil
config[:baz] # nil
```
