class Contract < ApplicationRecord
  belongs_to :company
  belongs_to :developer

  before_save :hi
  after_save :bye

  attr_accessor :hi_count, :bye_count

  def hi
    @hi_count ||= 0
    @hi_count += 1
  end

  def bye
    @bye_count ||= 0
    @bye_count += 1
  end
end
