*   Infer default `:inverse_of` option for `delegated_type` definitions.

    ```ruby
    class Entry < ApplicationRecord
      delegated_type :entryable, types: %w[ Message ]
      # => defaults to inverse_of: :entry
    end
    ```

    *Sean Doyle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activerecord/CHANGELOG.md) for previous changes.
