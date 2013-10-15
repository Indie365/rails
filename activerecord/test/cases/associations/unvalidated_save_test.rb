require "cases/helper"
require 'models/house'

class UnvalidatedSaveTest < ActiveRecord::TestCase
  fixtures :houses, :doors

  def test_save_validate_false
    return skip("foreign key support required - sqlite not supported") if current_adapter?(:SQLite3Adapter)
    # This passes
    door  = Door.new
    bad_house_id = House.order(:id).last.id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
  
  def test_save_validate_false_after_valid_test
    return skip("foreign key support required - sqlite not supported") if current_adapter?(:SQLite3Adapter)
    # This passess
    door  = Door.new
    # door.house = House.new # This would make the test fail below!!!
    bad_house_id = House.order(:id).last.id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end

  def test_save_validate_false_after_association_created
    return skip("foreign key support required - sqlite not supported") if current_adapter?(:SQLite3Adapter)
    # This fails due to the association having been set before the id is set to something invalid
    door  = Door.new
    door.house = House.new # This makes the test fail below!!!
    bad_house_id = House.order(:id).last.id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    # door.house # This would make it pass even with the above
    # door.valid? # This would also make it pass even with the above
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }  # Fails here
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end

  def test_save_validate_false_after_association_created_touched
    return skip("foreign key support required - sqlite not supported") if current_adapter?(:SQLite3Adapter)
    # This passes because the touch on door.house cleans the stale reference
    door  = Door.new
    door.house = House.new
    bad_house_id = House.order(:id).last.id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    door.house # This makes it pass
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
  
  def test_save_validate_false_after_valid_test_after_association_created
    return skip("foreign key support required - sqlite not supported") if current_adapter?(:SQLite3Adapter)
    # This passess as the valid? call has a useful side effect
    door  = Door.new
    door.house = House.new # This would make the test fail if it weren't for the valid test'
    bad_house_id = House.order(:id).last.id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    door.valid? # The valid? call means that the tests pass.
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
  
end