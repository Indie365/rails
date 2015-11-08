module Enumerable
  # Calculates a sum from the elements.
  #
  #  payments.sum { |p| p.price * p.tax_rate }
  #  payments.sum(&:price)
  #
  # The latter is a shortcut for:
  #
  #  payments.inject(0) { |sum, p| sum + p.price }
  #
  # It can also calculate the sum without the use of a block.
  #
  #  [5, 15, 10].sum # => 30
  #  ['foo', 'bar'].sum # => "foobar"
  #  [[1, 2], [3, 1, 5]].sum => [1, 2, 3, 1, 5]
  #
  # The default sum of an empty list is zero. You can override this default:
  #
  #  [].sum(Payment.new(0)) { |i| i.amount } # => Payment.new(0)
  def sum(identity = 0, &block)
    if block_given?
      map(&block).sum(identity)
    else
      inject(:+) || identity
    end
  end

  
  # Calculates a product by multiplying numeric elements
  # [5, 15, 10].mult # => 750
  #
  # returns nil if blank or any element is nil
  def mult(identity = 1, &block)
    return nil if (self.blank? || self.include?(nil))
    raise "All elements must be numeric" if self.any? { |x| x.is_a? String }

    if block_given?
      map(&block).mult(identity)
    else
      inject(:*) || identity
    end
  end 
   

  # Calculates a mean average of the elements
  def avg(identity = 0, &block)
    return nil if (self.blank? || self.include?(nil))
    raise "All elements must be numeric" if self.any? { |x| x.is_a? String }

    if block_given?
      map(&block).avg(identity)
    else
      (inject(:+).to_f / self.count) || identity
    end
  end 


  # Calculates a median average of the elements
  def median(identity = 0, &block)
    return nil if (self.blank? || self.include?(nil))
    raise "All elements must be numeric" if self.any? { |x| x.is_a? String }

    if block_given?
      map(&block).median(identity)
    else
      (self.sort[(self.length - 1) / 2] + self.sort[self.length / 2]) / 2.0 || identity
    end
  end   

  # Convert an enumerable to a hash.
  #
  #   people.index_by(&:login)
  #     => { "nextangle" => <Person ...>, "chade-" => <Person ...>, ...}
  #   people.index_by { |person| "#{person.first_name} #{person.last_name}" }
  #     => { "Chade- Fowlersburg-e" => <Person ...>, "David Heinemeier Hansson" => <Person ...>, ...}
  def index_by
    if block_given?
      Hash[map { |elem| [yield(elem), elem] }]
    else
      to_enum(:index_by) { size if respond_to?(:size) }
    end
  end

  # Returns +true+ if the enumerable has more than 1 element. Functionally
  # equivalent to <tt>enum.to_a.size > 1</tt>. Can be called with a block too,
  # much like any?, so <tt>people.many? { |p| p.age > 26 }</tt> returns +true+
  # if more than one person is over 26.
  def many?
    cnt = 0
    if block_given?
      any? do |element|
        cnt += 1 if yield element
        cnt > 1
      end
    else
      any? { (cnt += 1) > 1 }
    end
  end

  # The negative of the <tt>Enumerable#include?</tt>. Returns +true+ if the
  # collection does not include the object.
  def exclude?(object)
    !include?(object)
  end

  # Returns a copy of the enumerable without the specified elements.
  #
  #   ["David", "Rafael", "Aaron", "Todd"].without "Aaron", "Todd"
  #     => ["David", "Rafael"]
  #
  #   {foo: 1, bar: 2, baz: 3}.without :bar
  #     => {foo: 1, baz: 3}
  def without(*elements)
    reject { |element| elements.include?(element) }
  end

  # Convert an enumerable to an array based on the given key.
  #
  #   [{ name: "David" }, { name: "Rafael" }, { name: "Aaron" }].pluck(:name)
  #     => ["David", "Rafael", "Aaron"]
  #
  #   [{ id: 1, name: "David" }, { id: 2, name: "Rafael" }].pluck(:id, :name)
  #     => [[1, "David"], [2, "Rafael"]]
  def pluck(*keys)
    if keys.many?
      map { |element| keys.map { |key| element[key] } }
    else
      map { |element| element[keys.first] }
    end
  end
end

class Range #:nodoc:
  # Optimize range sum to use arithmetic progression if a block is not given and
  # we have a range of numeric values.
  def sum(identity = 0)
    if block_given? || !(first.is_a?(Integer) && last.is_a?(Integer))
      super
    else
      actual_last = exclude_end? ? (last - 1) : last
      if actual_last >= first
        (actual_last - first + 1) * (actual_last + first) / 2
      else
        identity
      end
    end
  end
end
