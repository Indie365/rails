class User
  include ActiveModel::Validations
  include ActiveModel::SecurePassword

  has_secure_password

  attr_accessor :password_digest
end
