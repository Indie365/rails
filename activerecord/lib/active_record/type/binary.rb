module ActiveRecord
  module Type
    class Binary < Value # :nodoc:
      def type
        :binary
      end

      def binary?
        true
      end

      def klass
        ::String
      end

      def type_cast_for_database(value)
        return if value.nil?
        Data.new(super)
      end

      def cast_value(value)
        if value.is_a?(Data)
          value.to_s
        else
          super
        end
      end

      class Data
        def initialize(value)
          @value = value
        end

        def to_s
          @value
        end

        def hex
          @value.unpack('H*')[0]
        end
      end
    end
  end
end
