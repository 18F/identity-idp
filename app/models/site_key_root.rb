# frozen_string_literal: true

# A user's per-site key root, wrapped under secrets only the user holds.
class SiteKeyRoot < ApplicationRecord
  WRAP_COLUMNS = %w[encrypted_root encrypted_root_recovery_code].freeze

  belongs_to :user

  validate :at_least_one_wrap

  def wraps
    slice(*WRAP_COLUMNS).compact
  end

  # A recovery code the user never confirmed saving cannot be counted on to open the root.
  def recoverable?
    encrypted_root_recovery_code.present? && recovery_code_acknowledged_at.present?
  end

  # A password reset cannot re-wrap the root, so only the password wrap is dropped. A root that
  # nothing else can open is deleted.
  def forget_password!
    return update!(encrypted_root: nil) if recoverable?

    destroy!
    user.association(:site_key_root).reset
  end

  private

  def at_least_one_wrap
    errors.add(:base, :blank) if wraps.empty?
  end
end
