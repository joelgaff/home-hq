class User < ApplicationRecord
  belongs_to :identity
  belongs_to :household
  has_one :person, dependent: :nullify

  delegate :email, to: :identity
end
