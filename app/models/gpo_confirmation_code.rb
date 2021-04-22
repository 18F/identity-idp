class GpoConfirmationCode < ApplicationRecord
  self.table_name = 'usps_confirmation_codes'

  belongs_to :profile

  def self.first_with_otp(otp)
    find do |gpo_confirmation_code|
      Pii::Fingerprinter.verify(
        Base32::Crockford.normalize(otp),
        gpo_confirmation_code.otp_fingerprint,
      )
    end
  end

  def expired?
    code_sent_at < IdentityConfig.store.usps_confirmation_max_days.days.ago
  end

  def safe_update_bounced_at_and_send_notification
    with_lock do
      return if bounced_at
      update_bounced_at_and_send_notification
    end
    true
  end

  def update_bounced_at_and_send_notification
    update(bounced_at: Time.zone.now)
    self.class.send_email(profile.user)
  end

  def self.send_email(user)
    user.confirmed_email_addresses.each do |email_address|
      UserMailer.undeliverable_address(user, email_address).deliver_now
    end
  end
end
