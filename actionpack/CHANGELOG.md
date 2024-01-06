*   Accept render options and block in `render` calls made with `:renderable`

    ```ruby
    class Greeting
      def render_in(view_context, **options, &block)
        if block
          view_context.render html: block.call
        else
          view_context.render inline: <<~ERB.strip, **options
            Hello, <%= local_assigns.fetch(:name, "World") %>!
          ERB
        end
      end
    end

    ApplicationController.render(Greeting.new)                                        # => "Hello, World!"
    ApplicationController.render(Greeting.new) { "Hello, Block!" }                    # => "Hello, Block!"
    ApplicationController.render(renderable: Greeting.new)                            # => "Hello, World!"
    ApplicationController.render(renderable: Greeting.new, locals: { name: "Local" }) # => "Hello, Local!"
    ```

    *Sean Doyle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionpack/CHANGELOG.md) for previous changes.
