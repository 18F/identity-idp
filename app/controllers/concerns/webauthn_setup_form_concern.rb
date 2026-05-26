# frozen_string_literal: true

# Shared helpers for controllers that render the WebAuthn credential-creation
# form (both the standard Users::WebauthnSetupController and the sign-up
# variant SignUp::WebauthnPlatformSetupController). Extracting these here means
# any change to how the form is prepared (presenter args, challenge generation,
# exclude-credentials logic) only needs to happen in one place.
module WebauthnSetupFormConcern
  extend ActiveSupport::Concern

  private

  def prepare_webauthn_setup_form(
    platform_authenticator:,
    auto_trigger:,
    need_to_set_up_additional_mfa:
  )
    save_challenge_in_session
    @exclude_credentials = exclude_credentials
    @platform_authenticator = platform_authenticator
    @auto_trigger = auto_trigger
    @presenter = build_webauthn_setup_presenter(platform_authenticator: @platform_authenticator)
    @need_to_set_up_additional_mfa = need_to_set_up_additional_mfa
    @account_creation_threatmetrix ||= account_creation_threatmetrix_variables
    user_session[:webauthn_setup_started_at] = Time.zone.now.to_f if platform_authenticator
  end

  # Saves a fresh WebAuthn creation challenge into the user session so the
  # JS package can read it when building the credential-creation options.
  def save_challenge_in_session
    credential_creation_options = WebAuthn::Credential.options_for_create(user: current_user)
    user_session[:webauthn_challenge] = credential_creation_options.challenge.bytes.to_a
  end

  # Returns the list of credential IDs already registered by the user so the
  # browser can exclude them from a new registration.
  def exclude_credentials
    current_user.webauthn_configurations.map(&:credential_id)
  end

  # Builds a WebauthnSetupPresenter with the standard set of arguments used by
  # both setup controllers.  Callers must set @platform_authenticator before
  # invoking this so the presenter receives the correct value.
  def build_webauthn_setup_presenter(platform_authenticator:)
    WebauthnSetupPresenter.new(
      current_user: current_user,
      user_fully_authenticated: user_fully_authenticated?,
      user_opted_remember_device_cookie: user_opted_remember_device_cookie,
      remember_device_default: remember_device_default,
      platform_authenticator: platform_authenticator,
      url_options:,
    )
  end
end
