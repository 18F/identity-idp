# frozen_string_literal: true

# A person's site key: a P-256 private key wrapped under secrets only they hold (their password
# and a recovery code), and its public key in the clear.
class SiteKey < ApplicationRecord
  WRAP_COLUMNS = %w[encrypted_private_key encrypted_private_key_recovery_code].freeze

  belongs_to :user

  validates :public_key, presence: true
  validate :at_least_one_wrap

  def wraps
    slice(*WRAP_COLUMNS).compact
  end

  # A recovery code the person never confirmed saving cannot be counted on to open the key.
  def recoverable?
    encrypted_private_key_recovery_code.present? && recovery_code_acknowledged_at.present?
  end

  # A password reset cannot rewrap the key, so only the password wrap is dropped. A key that
  # nothing else can open is deleted.
  def forget_password!
    return update!(encrypted_private_key: nil) if recoverable?

    destroy!
    user.association(:site_key).reset
  end

  private

  def at_least_one_wrap
    errors.add(:base, :blank) if wraps.empty?
  end
end
