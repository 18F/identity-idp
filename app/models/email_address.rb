# frozen_string_literal: true

class EmailAddress < ApplicationRecord
  include EncryptableAttribute

  before_destroy :reset_linked_identities

  encrypted_attribute_without_setter(name: :email)

  belongs_to :user, inverse_of: :email_addresses
  validates :encrypted_email, presence: true
  validates :email_fingerprint, presence: true
  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_one :suspended_email

  has_many :identities, class_name: 'ServiceProviderIdentity'
  # rubocop:enable Rails/HasManyOrHasOneDependent

  scope :confirmed, -> { where('confirmed_at IS NOT NULL') }

  def email=(email)
    set_encrypted_attribute(name: :email, value: email)
    self.email_fingerprint = email.present? ? encrypted_attributes[:email].fingerprint : ''
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirmation_period_expired?
    expiration_time = confirmation_sent_at +
                      IdentityConfig.store.add_email_link_valid_for_hours.hours
    Time.zone.now > expiration_time
  end

  def domain
    Mail::Address.new(email).domain
  end

  def fed_or_mil_email?
    fed_email? || mil_email?
  end

  def fed_email?
    FederalEmailDomain.fed_domain?(domain)
  end

  def mil_email?
    email.end_with?('.mil')
  end

  def self.last_sign_in
    order('last_sign_in_at DESC NULLS LAST').first
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

  private

  # Remove email id from all user identities
  # when the email is destroyed.
  def reset_linked_identities
    # rubocop:disable Rails/SkipsModelValidations
    ServiceProviderIdentity.where(
      user_id: user_id,
      email_address_id: id,
    ).update_all(email_address_id: nil)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
