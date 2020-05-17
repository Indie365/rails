# frozen_string_literal: true

require "cases/helper"
require "models/account"

SIGNED_ID_VERIFIER_TEST_SECRET = "This is normally set by the railtie initializer when used with Rails!"

ActiveRecord::Base.signed_id_verifier_secret = SIGNED_ID_VERIFIER_TEST_SECRET

class SignedIdTest < ActiveRecord::TestCase
  fixtures :accounts

  setup { @account = Account.first }

  test "find signed record" do
    assert_equal @account, Account.find_signed(@account.signed_id)
  end

  test "fail to find record from broken signed id" do
    assert_nil Account.find_signed("this won't find anything")
  end

  test "find signed record within expiration date" do
    assert_equal @account, Account.find_signed(@account.signed_id(expires_in: 1.minute))
  end

  test "fail to find signed record within expiration date" do
    signed_id = @account.signed_id(expires_in: 1.minute)
    travel 2.minutes
    assert_nil Account.find_signed(signed_id)
  end

  test "fail to work without a signed_id_verifier_secret" do
    begin
      ActiveRecord::Base.signed_id_verifier_secret = nil
      Account.instance_variable_set :@signed_id_verifier, nil

      assert_raises(ArgumentError) do
        @account.signed_id
      end
    ensure
      ActiveRecord::Base.signed_id_verifier_secret = SIGNED_ID_VERIFIER_TEST_SECRET
    end
  end
end
