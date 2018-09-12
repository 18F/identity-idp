class WebauthnConfiguration < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true
  validates :name, presence: true
  validates :credential_id, presence: true
  validates :credential_public_key, presence: true
end
