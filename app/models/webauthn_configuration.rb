class WebauthnConfiguration < ApplicationRecord
  belongs_to :user, inverse_of: :webauthn_configuration
  validates :user_id, presence: true
  validates :name, presence: true
  validates :credential_id, presence: true
  validates :credential_public_key, presence: true
end
