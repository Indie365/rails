# frozen_string_literal: true

class Zine < ActiveRecord::Base
  has_many :interests, inverse_of: :zine
  has_many :skills, inverse_of: :zine
end
