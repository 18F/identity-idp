module EmailAddressCallback
  extend ActiveSupport::Concern

  EMAIL_COLUMNS = %i[
    encrypted_email confirmation_token confirmed_at confirmation_sent_at email_fingerprint
  ].freeze

  def self.included(base)
    base.send(:after_save, :update_email_address)
  end

  def update_email_address
    if email_addresses.any?
      update_email_address_record if email_information_changed?
    elsif encrypted_email.present?
      create_full_email_address_record
    end
  end

  private

  def update_email_address_record
    email_addresses.take.update!(
      encrypted_email: encrypted_email,
      confirmation_token: confirmation_token,
      confirmed_at: confirmed_at,
      confirmation_sent_at: confirmation_sent_at,
      email_fingerprint: email_fingerprint,
    )
  end

  def create_full_email_address_record
    email_addresses.create!(
      user: self,
      encrypted_email: encrypted_email,
      confirmation_token: confirmation_token,
      confirmed_at: confirmed_at,
      confirmation_sent_at: confirmation_sent_at,
      email_fingerprint: email_fingerprint,
    )
    email_addresses.reload
  end

  def email_information_changed?
    EMAIL_COLUMNS.any? { |column| saved_change_to_attribute?(column) }
  end
end
