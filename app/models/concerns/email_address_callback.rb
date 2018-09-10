module EmailAddressCallback
  extend ActiveSupport::Concern

  def self.included(base)
    base.send(:after_save, :update_email_address)
  end

  def update_email_address
    if email_address.present?
      update_email_address_record
    elsif encrypted_email.present?
      create_full_email_address_record
    end
  end

  private

  def update_email_address_record
    email_address.update!(
      encrypted_email: encrypted_email,
      confirmation_token: confirmation_token,
      confirmed_at: confirmed_at,
      confirmation_sent_at: confirmation_sent_at,
      email_fingerprint: email_fingerprint
    )
  end

  def create_full_email_address_record
    create_email_address!(
      user: self,
      encrypted_email: encrypted_email,
      confirmation_token: confirmation_token,
      confirmed_at: confirmed_at,
      confirmation_sent_at: confirmation_sent_at,
      email_fingerprint: email_fingerprint
    )
  end
end
