class EmailAddress < ApplicationRecord
  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :email)

  belongs_to :user, inverse_of: :email_addresses
  validates :encrypted_email, presence: true
  validates :email_fingerprint, presence: true

  scope :confirmed, -> { where('confirmed_at IS NOT NULL') }

  def email=(email)
    set_encrypted_attribute(name: :email, value: email)
    self.email_fingerprint = email.present? ? encrypted_attributes[:email].fingerprint : ''
  end

  def confirmed?
    confirmed_at.present?
  end

  def stale_email_fingerprint?
    Pii::Fingerprinter.stale?(email, email_fingerprint)
  end

  def confirmation_period_expired?
    expiration_time = confirmation_sent_at +
                      IdentityConfig.store.add_email_link_valid_for_hours.hours
    Time.zone.now > expiration_time
  end

  class << self
    def find_with_email(email)
      return nil if !email.is_a?(String) || email.empty?

      email = email.downcase.strip
      email_fingerprints = create_fingerprints(email)
      find_by(email_fingerprint: email_fingerprints)
    end

    def find_with_confirmation_token(token)
      return if token.blank? || token.include?("\x00")
      EmailAddress.find_by(confirmation_token: token)
    end

    # It is possible for the same email address to exist more than once if it is unconfirmed,
    # but only one row with that email address can be confirmed.  This method finds the first email
    # address but will return the confirmed one first if it exists.
    def find_with_confirmed_or_unconfirmed_email(email)
      EmailAddress.order('confirmed_at ASC NULLS LAST').find_with_email(email)
    end

    def update_last_sign_in_at_on_user_id_and_email(user_id:, email:)
      return nil if email.to_s.empty?

      email = email.downcase.strip
      email_fingerprints = create_fingerprints(email)
      # rubocop:disable Rails/SkipsModelValidations
      EmailAddress.where(user_id: user_id, email_fingerprint: email_fingerprints).update_all(
        last_sign_in_at: Time.zone.now,
        updated_at: Time.zone.now,
      )
      # rubocop:enable Rails/SkipsModelValidations
    end

    private

    def create_fingerprints(email)
      [Pii::Fingerprinter.fingerprint(email), *Pii::Fingerprinter.previous_fingerprints(email)]
    end
  end
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: email_addresses
#
#  id                   :bigint           not null, primary key
#  confirmation_sent_at :datetime
#  confirmation_token   :string(255)
#  confirmed_at         :datetime
#  email_fingerprint    :string           default(""), not null
#  encrypted_email      :string           default(""), not null
#  last_sign_in_at      :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_id              :bigint
#
# Indexes
#
#  index_email_addresses_on_confirmation_token             (confirmation_token) UNIQUE
#  index_email_addresses_on_email_fingerprint              (email_fingerprint) UNIQUE WHERE (confirmed_at IS NOT NULL)
#  index_email_addresses_on_email_fingerprint_and_user_id  (email_fingerprint,user_id) UNIQUE
#  index_email_addresses_on_user_id                        (user_id)
#
# rubocop:enable Layout/LineLength
