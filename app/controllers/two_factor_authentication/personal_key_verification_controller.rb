# frozen_string_literal: true

module TwoFactorAuthentication
  class PersonalKeyVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include NewDeviceConcern

    prepend_before_action :authenticate_user
    before_action :check_personal_key_enabled

    def show
      recaptcha_annotation = annotate_recaptcha(
        RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
      )
      analytics.multi_factor_auth_enter_personal_key_visit(context: context, recaptcha_annotation:)
      @presenter = TwoFactorAuthCode::PersonalKeyPresenter.new
      @personal_key_form = PersonalKeyForm.new(current_user)
      @show_deprecation_warning = show_personal_key_deprecation_warning?
    end

    def create
      @personal_key_form = PersonalKeyForm.new(current_user, personal_key_param)
      result = @personal_key_form.submit
      handle_result(result)
    end

    private

    def analytics_properties
      mfa_created_at = current_user.encrypted_recovery_code_digest_generated_at
      {
        multi_factor_auth_method: 'personal-key',
        multi_factor_auth_method_created_at: mfa_created_at&.strftime('%s%L'),
        pii_like_keypaths: [[:errors, :personal_key], [:error_details, :personal_key]],
      }
    end

    def check_personal_key_enabled
      return if TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).enabled?

      redirect_to authentication_methods_setup_url
    end

    # Personal key MFA users see a Phase 1 deprecation warning telling them to set
    # up another authentication method before personal keys stop being supported.
    def show_personal_key_deprecation_warning?
      FeatureManagement.personal_key_mfa_deprecation_phase_1_enabled? &&
        TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).enabled?
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::PersonalKeyPresenter.new
    end

    def handle_result(result)
      handle_verification_for_authentication_context(
        result:,
        auth_method: TwoFactorAuthenticatable::AuthMethod::PERSONAL_KEY,
        extra_analytics: analytics_properties,
      )

      if result.success?
        # Capture the deprecation state before consuming the personal key, since
        # removing the recovery code changes PersonalKeyPolicy#enabled? and would
        # otherwise skip the Phase 1 add-MFA redirect below.
        @personal_key_mfa_deprecated = skip_personal_key_regeneration?

        _event, disavowal_token = create_user_event_with_disavowal(:personal_key_used)
        alert_user_about_personal_key_sign_in(disavowal_token)
        remove_personal_key

        handle_valid_otp
      else
        handle_invalid_mfa(type: 'personal_key', context:)
      end
    end

    def alert_user_about_personal_key_sign_in(disavowal_token)
      response = UserAlerts::AlertUserAboutPersonalKeySignIn.call(current_user, disavowal_token)
      analytics.personal_key_alert_about_sign_in(**response)
    end

    def remove_personal_key
      if skip_personal_key_regeneration?
        # During Phase 1 of personal key MFA deprecation we consume the personal
        # key on use: it is neither shown again nor regenerated, and the existing
        # recovery code is cleared so the user can no longer use or manage it.
        current_user.remove_recovery_code
        # Record that the key was just consumed so the add-MFA setup page can still
        # show the Phase 1 deprecation warning, even though the user no longer has
        # a recovery code (PersonalKeyPolicy#enabled? is now false).
        user_session[:personal_key_mfa_deprecated] = true
      else
        # for now we will regenerate a key and not show it to them so retire personal key page shows
        PersonalKeyGenerator.new(current_user).generate!
      end
      user_session.delete(:personal_key)
    end

    # During Phase 1 of personal key MFA deprecation, users who use a personal key
    # as an MFA method (i.e. not identity-verified) are no longer issued a new
    # personal key after authenticating with the old one. Identity-verified users,
    # who use their personal key for account recovery/IDV, are unaffected because
    # PersonalKeyPolicy#enabled? is false for them (they have profiles).
    #
    # We additionally require the user to have another (non-personal-key) MFA
    # method via MfaPolicy#two_factor_enabled?. Legacy users whose ONLY credential
    # is a personal key can reach this controller via a direct URL; consuming their
    # key would leave them with zero credentials and lock them out of their account.
    def skip_personal_key_regeneration?
      FeatureManagement.personal_key_mfa_deprecation_phase_1_enabled? &&
        TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).enabled? &&
        MfaPolicy.new(current_user).two_factor_enabled?
    end

    def personal_key_param
      params[:personal_key_form][:personal_key]
    end

    def handle_valid_otp
      if current_user.identity_verified? || current_user.password_reset_profile.present?
        redirect_to manage_personal_key_url
      elsif MfaPolicy.new(current_user).two_factor_enabled? &&
            !redirect_to_add_mfa_after_personal_key?
        redirect_to after_mfa_setup_path
      else
        redirect_to authentication_methods_setup_url
      end
    end

    # Route personal key MFA users to the authentication method setup page so they
    # see the Phase 1 deprecation warning and are prompted to add another method.
    # Uses the state captured before the personal key was consumed, because
    # removing the recovery code flips PersonalKeyPolicy#enabled? to false.
    def redirect_to_add_mfa_after_personal_key?
      FeatureManagement.enable_additional_mfa_redirect_for_personal_key_mfa? ||
        !!@personal_key_mfa_deprecated
    end
  end
end
