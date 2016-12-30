class ConfigHash < Hash
  class Processors
    class << self
      def constantize(v)
        case v
          when Symbol then v.to_s.start_with?(':') ? const_fetch(":#{v}", v) : v
          when String then v.start_with?('::')     ? const_fetch(v, v)       : v
          else v
        end
      end

      private

      def const_fetch(value, default)
        Object.const_defined?(value) ? Object.const_get(value) : default
      end
    end
  end
end
