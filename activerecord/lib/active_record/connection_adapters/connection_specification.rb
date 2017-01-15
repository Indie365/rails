require "uri"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification #:nodoc:
      attr_reader :name, :config, :adapter_method

      def initialize(name, config, adapter_method)
        @name, @config, @adapter_method = name, config, adapter_method
      end

      def initialize_dup(original)
        @config = original.config.dup
      end

      def to_hash
        @config.merge(name: @name)
      end

      class ConnectionConfigurations  < SimpleDelegator #:nodoc:
        attr_accessor :root_level

        def initialize(config)
          super
          @root_level = nil
        end

        def at(top_level)
          normalized(top_level)
        end

        def normalized(key = @root_level)
          config = key ? self[key] : self
          config = config.dup
          config ||= {}

          # if the configuration is a one level config, pushes that to be a two level config, with primary as key
          if !config.key?("primary") && config.key?("adapter")
            config = {"primary" => config}
          end

          if url = ENV["DATABASE_URL"]
            config["primary"] ||= {}
            config["primary"]["url"] ||= url

            r = ConnectionAdapters::ConnectionSpecification::Resolver.new(nil)
            config.each do |k, value|
              config[k] = r.resolve(value) if value
            end
          end
          config
        end
      end

      # Expands a connection string into a hash.
      class ConnectionUrlResolver # :nodoc:
        # == Example
        #
        #   url = "postgresql://foo:bar@localhost:9000/foo_test?pool=5&timeout=3000"
        #   ConnectionUrlResolver.new(url).to_hash
        #   # => {
        #     "adapter"  => "postgresql",
        #     "host"     => "localhost",
        #     "port"     => 9000,
        #     "database" => "foo_test",
        #     "username" => "foo",
        #     "password" => "bar",
        #     "pool"     => "5",
        #     "timeout"  => "3000"
        #   }
        def initialize(url)
          raise "Database URL cannot be empty" if url.blank?
          @uri     = uri_parser.parse(url)
          @adapter = @uri.scheme && @uri.scheme.tr("-", "_")
          @adapter = "postgresql" if @adapter == "postgres"

          if @uri.opaque
            @uri.opaque, @query = @uri.opaque.split("?", 2)
          else
            @query = @uri.query
          end
        end

        # Converts the given URL to a full connection hash.
        def to_hash
          config = raw_config.reject { |_, value| value.blank? }
          config.map { |key, value| config[key] = uri_parser.unescape(value) if value.is_a? String }
          config
        end

        private

          def uri
            @uri
          end

          def uri_parser
            @uri_parser ||= URI::Parser.new
          end

          # Converts the query parameters of the URI into a hash.
          #
          #   "localhost?pool=5&reaping_frequency=2"
          #   # => { "pool" => "5", "reaping_frequency" => "2" }
          #
          # returns empty hash if no query present.
          #
          #   "localhost"
          #   # => {}
          def query_hash
            Hash[(@query || "").split("&").map { |pair| pair.split("=") }]
          end

          def raw_config
            if uri.opaque
              query_hash.merge(
                "adapter"  => @adapter,
                "database" => uri.opaque)
            else
              query_hash.merge(
                "adapter"  => @adapter,
                "username" => uri.user,
                "password" => uri.password,
                "port"     => uri.port,
                "database" => database_from_path,
                "host"     => uri.hostname)
            end
          end

          # Returns name of the database.
          def database_from_path
            if @adapter == "sqlite3"
              # 'sqlite3:/foo' is absolute, because that makes sense. The
              # corresponding relative version, 'sqlite3:foo', is handled
              # elsewhere, as an "opaque".

              uri.path
            else
              # Only SQLite uses a filename as the "database" name; for
              # anything else, a leading slash would be silly.

              uri.path.sub(%r{^/}, "")
            end
          end
      end

      ##
      # Builds a ConnectionSpecification from user input.
      class Resolver # :nodoc:
        attr_reader :configurations

        # Accepts a hash two layers deep, keys on the first layer represent
        # the specification name, such as "primary".
        #
        # Keys must be strings.
        def initialize(configurations)
          @configurations = configurations
        end

        # Returns a hash with database connection information.
        #
        # == Examples
        #
        # Full hash Configuration.
        #
        #   configurations = { "primary" => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3" } }
        #   Resolver.new(configurations).resolve(:primary)
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3"}
        #
        # Initialized with URL configuration strings.
        #
        #   configurations = { "primary" => "postgresql://localhost/foo" }
        #   Resolver.new(configurations).resolve(:primary)
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "postgresql" }
        #
        def resolve(config)
          if config
            resolve_connection config
          else
            raise AdapterNotSpecified
          end
        end

        # Returns an instance of ConnectionSpecification for a given adapter.
        # Accepts:
        # - Hash: one layer deep Hash that contains all connection information
        # - Symbol: a configuration name that will be looked-up
        #           from the configurations Hash
        # - String: a database url
        #
        # == Example
        #
        #   config = { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3" }
        #   spec = Resolver.new({}).spec(config)
        #   spec.adapter_method
        #   # => "sqlite3_connection"
        #   spec.config
        #   # => { "host" => "localhost", "database" => "foo", "adapter" => "sqlite3" }
        #
        def spec(config)
          spec = resolve(config).symbolize_keys

          raise(AdapterNotSpecified, "database configuration does not specify adapter") unless spec.key?(:adapter)

          path_to_adapter = "active_record/connection_adapters/#{spec[:adapter]}_adapter"
          begin
            require path_to_adapter
          rescue Gem::LoadError => e
            raise Gem::LoadError, "Specified '#{spec[:adapter]}' for database adapter, but the gem is not loaded. Add `gem '#{e.name}'` to your Gemfile (and ensure its version is at the minimum required by ActiveRecord)."
          rescue LoadError => e
            raise LoadError, "Could not load '#{path_to_adapter}'. Make sure that the adapter in config/database.yml is valid. If you use an adapter other than 'mysql2', 'postgresql' or 'sqlite3' add the necessary adapter gem to the Gemfile.", e.backtrace
          end

          adapter_method = "#{spec[:adapter]}_connection"

          unless ActiveRecord::Base.respond_to?(adapter_method)
            raise AdapterNotFound, "database configuration specifies nonexistent #{spec.config[:adapter]} adapter"
          end

          ConnectionSpecification.new(spec.delete(:name) || "primary", spec, adapter_method)
        end

        private

          # Returns fully resolved connection, accepts hash, string or symbol.
          # Always returns a hash.
          #
          # == Examples
          #
          # Symbol representing current environment.
          #
          #   Resolver.new("primary" => {}).resolve_connection(:primary)
          #   # => {}
          #
          # One layer deep hash of connection values.
          #
          #   Resolver.new({}).resolve_connection("adapter" => "sqlite3")
          #   # => { "adapter" => "sqlite3" }
          #
          # Connection URL.
          #
          #   Resolver.new({}).resolve_connection("postgresql://localhost/foo")
          #   # => { "host" => "localhost", "database" => "foo", "adapter" => "postgresql" }
          #
          def resolve_connection(spec)
            case spec
            when Symbol
              resolve_symbol_connection spec
            when String
              resolve_url_connection spec
            when Hash
              resolve_hash_connection spec
            end
          end

          # Takes the specification name such as +:primary+.
          # This requires that the @configurations was initialized with a key that
          # matches.
          #
          #   Resolver.new("primary" => {}).resolve_symbol_connection(:primary)
          #   # => {}
          #
          def resolve_symbol_connection(spec)
            if config = configurations[spec.to_s]
              resolve_connection(config).merge("name" => spec.to_s)
            else
              raise(AdapterNotSpecified, "'#{spec}' database is not configured. Available: #{configurations.keys.inspect}")
            end
          end

          # Accepts a hash. Expands the "url" key that contains a
          # URL database connection to a full connection
          # hash and merges with the rest of the hash.
          # Connection details inside of the "url" key win any merge conflicts
          def resolve_hash_connection(spec)
            if spec["url"] && spec["url"] !~ /^jdbc:/
              connection_hash = resolve_url_connection(spec.delete("url"))
              spec.merge!(connection_hash)
            end
            spec
          end

          # Takes a connection URL.
          #
          #   Resolver.new({}).resolve_url_connection("postgresql://localhost/foo")
          #   # => { "host" => "localhost", "database" => "foo", "adapter" => "postgresql" }
          #
          def resolve_url_connection(url)
            ConnectionUrlResolver.new(url).to_hash
          end
      end
    end
  end
end
