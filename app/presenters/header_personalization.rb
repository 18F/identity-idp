# frozen_string_literal: true

# Personalization shown in the account header chrome, shared by the account
# homepage (AccountHomePresenter) and the account settings page
# (AccountShowPresenter). The including presenter must expose `user` and
# `decrypted_pii`.
module HeaderPersonalization
  # First name when the account is verified (decrypted PII present), otherwise
  # the address the user most recently signed in with.
  def header_personalization
    return decrypted_pii.first_name if decrypted_pii.present?

    user.last_sign_in_email_address.email
  end
end
