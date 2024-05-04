*   `ActiveRecord::Encryption::Encryptor` now supports a `:compressor` option to customize the compression algorithm used.

    ```ruby
    module ZstdCompressor
      def self.deflate(data)
        Zstd.compress(data)
      end

      def self.inflate(data)
        Zstd.decompress(data)
      end
    end

    class User
      encrypts :name, encryptor: ActiveRecord::Encryption::Encryptor.new(compressor: ZstdCompressor)
    end
    ```

    *heka1024*

*   Add public method for checking if a table is ignored by the schema cache.

    Previously, an application would need to reimplement `ignored_table?` from the schema cache class to check if a table was set to be ignored. This adds a public method to support this and updates the schema cache to use that directly.

    ```ruby
    ActiveRecord.schema_cache_ignored_tables = ["developers"]
    ActiveRecord.schema_cache_ignored_table?("developers")
    => true
    ```

    *Eileen M. Uchitelle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activerecord/CHANGELOG.md) for previous changes.
