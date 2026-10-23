# frozen_string_literal: true

# A user's per-site key root: a P-256 private key wrapped under their password, and its public
# key in the clear.
class SiteKeyRoot < ApplicationRecord
  belongs_to :user

  validates :encrypted_root, presence: true
  validates :public_key, presence: true

  # A password reset cannot re-wrap the root, so it is deleted.
  def forget_password!
    destroy!
    user.association(:site_key_root).reset
  end
end
