require 'active_support/core_ext/string/output_safety'
require 'set'

module ActionView
  # = Action View Tag Helpers
  module Helpers #:nodoc:
    # Provides methods to generate HTML tags programmatically both as a modern 
    # HTML5 compliant builder style and legacy XHTML compliant tags.
    module TagHelper
      extend ActiveSupport::Concern

      BOOLEAN_ATTRIBUTES = %w(disabled readonly multiple checked autobuffer
                           autoplay controls loop selected hidden scoped async
                           defer reversed ismap seamless muted required
                           autofocus novalidate formnovalidate open pubdate
                           itemscope allowfullscreen default inert sortable
                           truespeed typemustmatch).to_set

      BOOLEAN_ATTRIBUTES.merge(BOOLEAN_ATTRIBUTES.map(&:to_sym))

      TAG_PREFIXES = ['aria', 'data', :aria, :data].to_set

      PRE_CONTENT_STRINGS             = Hash.new { "".freeze }
      PRE_CONTENT_STRINGS[:textarea]  = "\n"
      PRE_CONTENT_STRINGS["textarea"] = "\n"

      class TagBuilder #:nodoc:
        include CaptureHelper
        include OutputSafetyHelper

        VOID_ELEMENTS = %i(base br col embed hr img input keygen link meta
        param source track wbr).to_set

        def initialize(view_context)
          @view_context = view_context
        end

        def tag_string(name, content = nil, escape_attributes: true, **options, &block)
          content = @view_context.capture(self, &block) if block_given?
          if VOID_ELEMENTS.include?(name) && content.nil?
            "<#{name}#{tag_options(options, escape_attributes)}>".html_safe
          else
            content_tag_string(name, content || '', options, escape_attributes)
          end
        end

        def content_tag_string(name, content, options, escape = true)
          tag_options = tag_options(options, escape) if options
          content     = ERB::Util.unwrapped_html_escape(content) if escape
          "<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name}>".html_safe
        end

        def tag_options(options, escape = true)
          return if options.blank?
          output = ""
          sep    = " ".freeze
          options.each_pair do |key, value|
            if TAG_PREFIXES.include?(key) && value.is_a?(Hash)
              value.each_pair do |k, v|
                next if v.nil?
                output << sep
                output << prefix_tag_option(key, k, v, escape)
              end
            elsif BOOLEAN_ATTRIBUTES.include?(key)
              if value
                output << sep
                output << boolean_tag_option(key)
              end
            elsif !value.nil?
              output << sep
              output << tag_option(key, value, escape)
            end
          end
          output unless output.empty?
        end

        def boolean_tag_option(key)
          %(#{key}="#{key}")
        end

        def tag_option(key, value, escape)
          if value.is_a?(Array)
            value = escape ? safe_join(value, " ".freeze) : value.join(" ".freeze)
          else
            value = escape ? ERB::Util.unwrapped_html_escape(value) : value
          end
          %(#{key}="#{value}")
        end

        private
          def prefix_tag_option(prefix, key, value, escape)
            key = "#{prefix}-#{key.to_s.dasherize}"
            unless value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(BigDecimal)
              value = value.to_json
            end
            tag_option(key, value, escape)
          end

          def respond_to_missing?(method_name, include_private = false)
            true
          end

          def method_missing(called, *args, &block)
            tag_string(called, *args, &block)
          end

      end

      # Returns an HTML tag. Supports two syntax variants: legacy and modern.
      #
      # === Modern syntax
      # Modern syntax follows one of two formats:
      #   tag.<name>(options)
      #   tag.<name>(content, options)
      # Returns an HTML tag. Content has to be a string. If content is passed
      # than tag is surrounding the content. Otherwise tag will be empty. You
      # can also use a block to pass the content inside ERB templates. Result
      # is by default HTML5 compliant. Include +escape_attributes+: +false+ 
      # in options to disable attribute value escaping. The tag will be
      # generated with related closing tag unless tag represents a
      # void[https://www.w3.org/TR/html5/syntax.html#void-elements] element.
      #
      # ==== Options
      # Like with traditional syntax the options hash can be used with
      # attributes with no value (like disabled and readonly), which you can
      # give a value of true in the options hash. You can use symbols or
      # strings for the attribute names.
      #    
      # ==== Examples
      #   tag.span
      #   # => <span></span>
      #
      #   tag.span(class: "bookmark")
      #   # => <span class=\"bookmark\"></span>
      #
      #   tag.input type: 'text', disabled: true
      #   # => <input type="text" disabled="disabled">
      #
      #   tag.input type: 'text', class: ["strong", "highlight"]
      #   # => <input class="strong highlight" type="text">
      #
      #   tag.img src: "open & shut.png"
      #   # => <img src="open &amp; shut.png">
      #
      #   tag.img(src: "open & shut.png", escape_attributes: false)
      #   # => <img src="open & shut.png">
      #
      #   tag.div(data: {name: 'Stephen', city_state: %w(Chicago IL)})
      #   # => <div data-name="Stephen" data-city-state="[&quot;Chicago&quot;,&quot;IL&quot;]"></div>
      #
      #   tag.p "Hello world!"
      #   # => <p>Hello world!</p>
      #
      #   tag.div tag.p("Hello world!"), class: "strong"
      #   # => <div class="strong"><p>Hello world!</p></div>
      #
      #   tag.div "Hello world!", class: ["strong", "highlight"]
      #   # => <div class="strong highlight">Hello world!</div>
      #
      #   tag.select options, multiple: true
      #   # => <select multiple="multiple">...options...</select>
      #
      #   <%= tag.div class: "strong" do %>
      #     Hello world!
      #   <% end %>
      #   # => <div class="strong">Hello world!</div>
      #
      #   <%= tag.div class: "strong" do |t| %>
      #     <% tag.p("Hello world!") %>
      #   <% end %>
      #   # => <div class="strong"><p>Hello world!</p></div>
      #
      # === Legacy syntax
      # Returns an empty HTML tag of type +name+ which by default is XHTML
      # compliant. Set +open+ to true to create an open tag compatible
      # with HTML 4.0 and below. Add HTML attributes by passing an attributes
      # hash to +options+. Set +escape+ to false to disable attribute value
      # escaping.
      #
      # ==== Options
      # You can use symbols or strings for the attribute names.
      #
      # Use +true+ with boolean attributes that can render with no value, like
      # +disabled+ and +readonly+.
      #
      # HTML5 <tt>data-*</tt> attributes can be set with a single +data+ key
      # pointing to a hash of sub-attributes.
      #
      # To play nicely with JavaScript conventions sub-attributes are dasherized.
      # For example, a key +user_id+ would render as <tt>data-user-id</tt> and
      # thus accessed as <tt>dataset.userId</tt>.
      #
      # Values are encoded to JSON, with the exception of strings, symbols and
      # BigDecimals.
      # This may come in handy when using jQuery's HTML5-aware <tt>.data()</tt>
      # from 1.4.3.
      #
      # ==== Examples
      #   tag("br")
      #   # => <br />
      #
      #   tag("br", nil, true)
      #   # => <br>
      #
      #   tag("input", type: 'text', disabled: true)
      #   # => <input type="text" disabled="disabled" />
      #
      #   tag("input", type: 'text', class: ["strong", "highlight"])
      #   # => <input class="strong highlight" type="text" />
      #
      #   tag("img", src: "open & shut.png")
      #   # => <img src="open &amp; shut.png" />
      #
      #   tag("img", {src: "open &amp; shut.png"}, false, false)
      #   # => <img src="open &amp; shut.png" />
      #
      #   tag("div", data: {name: 'Stephen', city_state: %w(Chicago IL)})
      #   # => <div data-name="Stephen" data-city-state="[&quot;Chicago&quot;,&quot;IL&quot;]" />
      def tag(name = nil, options = nil, open = false, escape = true)
        if name.nil?
          tag_builder
        else
          "<#{name}#{tag_builder.tag_options(options, escape) if options}#{open ? ">" : " />"}".html_safe
        end
      end

      # Returns an HTML block tag of type +name+ surrounding the +content+. Add
      # HTML attributes by passing an attributes hash to +options+.
      # Instead of passing the content as an argument, you can also use a block
      # in which case, you pass your +options+ as the second parameter.
      # Set escape to false to disable attribute value escaping.
      # Note: this is legacy syntax, see +tag+ method description for details.
      #
      # ==== Options
      # The +options+ hash can be used with attributes with no value like (<tt>disabled</tt> and
      # <tt>readonly</tt>), which you can give a value of true in the +options+ hash. You can use
      # symbols or strings for the attribute names.
      #
      # ==== Examples
      #   content_tag(:p, "Hello world!")
      #    # => <p>Hello world!</p>
      #   content_tag(:div, content_tag(:p, "Hello world!"), class: "strong")
      #    # => <div class="strong"><p>Hello world!</p></div>
      #   content_tag(:div, "Hello world!", class: ["strong", "highlight"])
      #    # => <div class="strong highlight">Hello world!</div>
      #   content_tag("select", options, multiple: true)
      #    # => <select multiple="multiple">...options...</select>
      #
      #   <%= content_tag :div, class: "strong" do -%>
      #     Hello world!
      #   <% end -%>
      #    # => <div class="strong">Hello world!</div>
      def content_tag(name, content_or_options_with_block = nil, options = nil, escape = true, &block)
        if block_given?
          options = content_or_options_with_block if content_or_options_with_block.is_a?(Hash)
          tag_builder.content_tag_string(name, capture(&block), options, escape)
        else
          tag_builder.content_tag_string(name, content_or_options_with_block, options, escape)
        end
      end

      # Returns a CDATA section with the given +content+. CDATA sections
      # are used to escape blocks of text containing characters which would
      # otherwise be recognized as markup. CDATA sections begin with the string
      # <tt><![CDATA[</tt> and end with (and may not contain) the string <tt>]]></tt>.
      #
      #   cdata_section("<hello world>")
      #   # => <![CDATA[<hello world>]]>
      #
      #   cdata_section(File.read("hello_world.txt"))
      #   # => <![CDATA[<hello from a text file]]>
      #
      #   cdata_section("hello]]>world")
      #   # => <![CDATA[hello]]]]><![CDATA[>world]]>
      def cdata_section(content)
        splitted = content.to_s.gsub(/\]\]\>/, ']]]]><![CDATA[>')
        "<![CDATA[#{splitted}]]>".html_safe
      end

      # Returns an escaped version of +html+ without affecting existing escaped entities.
      #
      #   escape_once("1 < 2 &amp; 3")
      #   # => "1 &lt; 2 &amp; 3"
      #
      #   escape_once("&lt;&lt; Accept & Checkout")
      #   # => "&lt;&lt; Accept &amp; Checkout"
      def escape_once(html)
        ERB::Util.html_escape_once(html)
      end

      private
        def tag_builder
          @tag_builder ||= TagBuilder.new(self)
        end
    end
  end
end
