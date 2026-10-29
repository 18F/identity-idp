# frozen_string_literal: true

# Records a user's consent for an STS (token exchange) broker service provider.
# Separate from the general authorization consent captured on the identities table.
class UserConsentSts < ApplicationRecord
  self.table_name = :user_consent_sts

  belongs_to :user, inverse_of: :sts_consents

  validates :user, presence: true
  validates :target_app, presence: true

  scope :unexpired, -> { where(created_at: consent_expiration.ago..) }

  # Returns true when an unexpired consent exists for the given user and target_app.
  def self.consent_valid?(user:, target_app:)
    consent = find_by(user: user, target_app: target_app)
    return false if consent.blank?

    consent.unexpired?
  end

  def unexpired?
    created_at > self.class.consent_expiration.ago
  end

  def self.consent_expiration
    IdentityConfig.store.sts_consent_expiration_in_days.days
  end
end
