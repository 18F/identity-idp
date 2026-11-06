# frozen_string_literal: true

# A person's site key: a P-256 private key wrapped under their password, and its public key in
# the clear.
class SiteKey < ApplicationRecord
  belongs_to :user

  validates :public_key, presence: true

  # A password reset cannot rewrap the key, and nothing else can open it, so the row goes and
  # the next sign-in to a listed client makes a new pair.
  def forget_password!
    destroy!
    user.association(:site_key).reset
  end
end
