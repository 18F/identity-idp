# frozen_string_literal: true

# Source of truth for "which of the user's email addresses goes with this
# service provider?"
#
#   sp_email_preference_id  - the user's explicit choice, or nil. SAFE TO PERSIST.
#   sp_email_id_for_display - what to show the user. Always present. DISPLAY ONLY.
#
module SpSharedEmailConcern
  private

  def selected_email_for_linked_identity
    return if current_user.blank?

    selected_email_id = user_session[:selected_email_id_for_linked_identity]
    return if selected_email_id.blank?

    email_address = current_user.confirmed_email_addresses.find_by(id: selected_email_id)
    clear_selected_email_for_linked_identity! if email_address.nil?
    email_address
  end

  def selected_email_id_for_linked_identity
    selected_email_for_linked_identity&.id
  end

  def clear_selected_email_for_linked_identity!
    user_session.delete(:selected_email_id_for_linked_identity)
  end

  # The user's identity record for the SP in the current session, or nil when
  # they have not connected to this SP yet.
  def sp_linked_identity
    current_user&.identities&.find_by(service_provider: sp_session[:issuer])
  end

  def sp_email_preference_id
    selected_email_id_for_linked_identity || sp_linked_identity&.email_address_id
  end

  def sp_email_preference_id_for_auth
    identity = sp_linked_identity
    return nil unless identity&.verified_single_email_attribute?

    selected_email_id_for_linked_identity || identity.email_address_id
  end

  def sp_email_id_for_display
    sp_email_preference_id || current_user.last_sign_in_email_address.id
  end
end
