class MemberDetail < ActiveRecord::Base
  belongs_to :member
  belongs_to :organization
  has_one :member_type, through: :member

  has_many :organization_member_details, through: :organization, source: :member_details
end
