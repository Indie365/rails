require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/hash/conversions'
require 'active_support/core_ext/hash/slice'

module ActiveModel
  module Serializers
    # == Active Model XML Serializer
    module Xml
      extend ActiveSupport::Concern
      include ActiveModel::Serialization

      included do
        extend ActiveModel::Naming
      end

      class Serializer #:nodoc:
        class Attribute #:nodoc:
          attr_reader :name, :value, :type

          def initialize(name, serializable, value)
            @name, @serializable = name, serializable
            value  = value.in_time_zone if value.respond_to?(:in_time_zone)
            @value = value
            @type  = compute_type
          end

          def decorations
            decorations = {}
            decorations[:encoding] = 'base64' if type == :binary
            decorations[:type] = (type == :string) ? nil : type
            decorations[:nil] = true if value.nil?
            decorations
          end

        protected

          def compute_type
            return if value.nil?
            type = ActiveSupport::XmlMini::TYPE_NAMES[value.class.name]
            type ||= :string if value.respond_to?(:to_str)
            type ||= :yaml
            type
          end
        end

        class MethodAttribute < Attribute #:nodoc:
        end

        attr_reader :options

        def initialize(serializable, options = nil)
          @serializable = serializable
          @options = options ? options.dup : {}
        end

        def serializable_hash
          @serializable.serializable_hash(@options.except(:include))
        end

        def serializable_collection
          methods = Array.wrap(options[:methods]).map(&:to_s)
          serializable_hash.map do |name, value|
            name = name.to_s
            if methods.include?(name)
              self.class::MethodAttribute.new(name, @serializable, value)
            else
              self.class::Attribute.new(name, @serializable, value)
            end
          end
        end

        def serialize
          require 'builder' unless defined? ::Builder

          options[:indent]  ||= 2
          options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])

          @builder = options[:builder]
          @builder.instruct! unless options[:skip_instruct]

          root = (options[:root] || @serializable.class.model_name.element).to_s
          root = ActiveSupport::XmlMini.rename_key(root, options)

          args = [root]
          args << {:xmlns => options[:namespace]} if options[:namespace]
          args << {:type => options[:type]} if options[:type] && !options[:skip_types]

          @builder.tag!(*args) do
            add_attributes_and_methods
            add_includes
            add_extra_behavior
            add_procs
            yield @builder if block_given?
          end
        end

      private

        def add_extra_behavior
        end

        def add_attributes_and_methods
          serializable_collection.each do |attribute|
            key = ActiveSupport::XmlMini.rename_key(attribute.name, options)
            ActiveSupport::XmlMini.to_tag(key, attribute.value,
              options.merge(attribute.decorations))
          end
        end

        def add_includes
          @serializable.send(:serializable_add_includes, options) do |association, records, opts|
            add_associations(association, records, opts)
          end
        end

        # TODO This can likely be cleaned up to simple use ActiveSupport::XmlMini.to_tag as well.
        def add_associations(association, records, opts)
          merged_options = opts.merge(options.slice(:builder, :indent))
          merged_options[:skip_instruct] = true

          if records.is_a?(Enumerable)
            tag  = ActiveSupport::XmlMini.rename_key(association.to_s, options)
            type = options[:skip_types] ? { } : {:type => "array"}
            association_name = association.to_s.singularize
            merged_options[:root] = association_name

            if records.empty?
              @builder.tag!(tag, type)
            else
              @builder.tag!(tag, type) do
                records.each do |record|
                  if options[:skip_types]
                    record_type = {}
                  else
                    record_class = (record.class.to_s.underscore == association_name) ? nil : record.class.name
                    record_type = {:type => record_class}
                  end

                  record.to_xml merged_options.merge(record_type)
                end
              end
            end
          else
            merged_options[:root] = association.to_s
            association_name = association.to_s.tableize.singularize
            record_type = { :type => ((records.class.to_s.underscore == association_name) ? nil : records.class.name) }
            records.to_xml merged_options.merge(record_type)
          end
        end

        def add_procs
          if procs = options.delete(:procs)
            Array.wrap(procs).each do |proc|
              if proc.arity == 1
                proc.call(options)
              else
                proc.call(options, @serializable)
              end
            end
          end
        end
      end

      # Returns XML representing the model. Configuration can be
      # passed through +options+.
      #
      # Without any +options+, the returned XML string will include all the model's
      # attributes. For example:
      #
      #   user = User.find(1)
      #   user.to_xml
      #
      #   <?xml version="1.0" encoding="UTF-8"?>
      #   <user>
      #     <id type="integer">1</id>
      #     <name>David</name>
      #     <age type="integer">16</age>
      #     <created-at type="datetime">2011-01-30T22:29:23Z</created-at>
      #   </user>
      #
      # The <tt>:only</tt> and <tt>:except</tt> options can be used to limit the attributes
      # included, and work similar to the +attributes+ method.
      #
      # To include the result of some method calls on the model use <tt>:methods</tt>.
      #
      # To include associations use <tt>:include</tt>.
      #
      # For further documentation see activerecord/lib/active_record/serializers/xml_serializer.xml.
      def to_xml(options = {}, &block)
        Serializer.new(self, options).serialize(&block)
      end

      def from_xml(xml)
        self.attributes = Hash.from_xml(xml).values.first
        self
      end
    end
  end
end
