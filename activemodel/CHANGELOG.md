*   Add `ActiveModel::Validations::ModelValidator`

    This validator is similar to `ActiveRecord::Validations::AssociatedValidator`
    but doesn't require the associated object to be an `ActiveRecord` object.

    It is useful when building form objects that aren't backed by a database or
    to save multiple objects at once.

    Ex:

        class Author
          include ActiveModel::Model

          validates_presence_of :name
        end

        class Book
          include ActiveModel::Model

          attr_accessor :author, :title

          validates_model :author
        end

        author = Author.new
        book = Book.new(title: "A book", author: author)
        book.valid? # => false

        book.errors[:author] # => ["is invalid"]
        author.errors[:name] # => ["can't be blank"]

    *Matheus Richard*

*   Port the `type_for_attribute` method to Active Model. Classes that include
    `ActiveModel::Attributes` will now provide this method. This method behaves
    the same for Active Model as it does for Active Record.

      ```ruby
      class MyModel
        include ActiveModel::Attributes

        attribute :my_attribute, :integer
      end

      MyModel.type_for_attribute(:my_attribute) # => #<ActiveModel::Type::Integer ...>
      ```

    *Jonathan Hefner*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
