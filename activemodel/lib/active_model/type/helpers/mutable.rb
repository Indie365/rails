# frozen_string_literal: true

module ActiveModel
  module Type
    module Helpers # :nodoc: all
      module Mutable
        def immutable_value(value)
          value.isolated_copy
        end

        def cast(value)
          deserialize(serialize(value))
        end

        # +raw_old_value+ will be the `_before_type_cast` version of the
        # value (likely a string). +new_value+ will be the current, type
        # cast value.
        def changed_in_place?(raw_old_value, new_value)
          raw_old_value != serialize(new_value)
        end
      end
    end
  end
end
