require_relative 'interaction_helper'
require_relative 'javascript_driver_helper'

module IdvHelper
  include ActiveJob::TestHelper
  include InteractionHelper

  def self.included(base)
    base.class_eval { include JavascriptDriverHelper }
  end

  def user_password
    Features::SessionHelper::VALID_PASSWORD
  end

  def fill_out_phone_form_ok(phone = '415-555-0199')
    fill_in :idv_phone_form_phone, with: phone
  end

  # Fill out the phone form with a phone that's already been confirmed so the app will skip sending
  # the token it would have to send for a new, unconfirmed number
  def fill_out_phone_form_mfa_phone(user)
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
  end

  def fill_out_phone_form_fail
    fill_in :idv_phone_form_phone, with: '(703) 555-5555'
  end

  def click_idv_continue
    click_spinner_button_and_wait t('forms.buttons.continue')
  end

  def click_idv_select
    click_select_button_and_wait t('in_person_proofing.body.location.location_button')
  end

  def choose_idv_otp_delivery_method_sms
    page.find(
      'label',
      text: t('two_factor_authentication.otp_delivery_preference.sms'),
      wait: 5,
    ).click
    click_on t('idv.buttons.send_confirmation_code')
  end

  def choose_idv_otp_delivery_method_voice
    page.find(
      'label',
      text: t('two_factor_authentication.otp_delivery_preference.voice'),
    ).click
    click_on t('idv.buttons.send_confirmation_code')
  end

  def visit_idp_from_sp_with_ial2(sp, **extra)
    if sp == :saml
      visit_idp_from_saml_sp_with_ial2
    elsif sp == :oidc
      @state = SecureRandom.hex
      @client_id = sp_oidc_issuer
      @nonce = SecureRandom.hex
      visit_idp_from_oidc_sp_with_ial2(state: @state, client_id: @client_id, nonce: @nonce, **extra)
    end
  end

  def sp_oidc_redirect_uri
    'http://localhost:7654/auth/result'
  end

  def sp_oidc_issuer
    'urn:gov:gsa:openidconnect:sp:server'
  end

  def service_provider_issuer(sp)
    if sp == :saml
      sp1_issuer
    elsif sp == :oidc
      sp_oidc_issuer
    end
  end

  def visit_idp_from_saml_sp_with_ial2(issuer: sp1_issuer)
    saml_overrides = {
      issuer: issuer,
      authn_context: [
        Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
        "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
      ],
      security: {
        embed_sign: false,
      },
    }
    if javascript_enabled?
      service_provider = ServiceProvider.find_by(issuer: sp1_issuer)
      acs_url = URI.parse(service_provider.acs_url)
      acs_url.host = page.server.host
      acs_url.port = page.server.port
      service_provider.update(acs_url: acs_url.to_s)
    end
    visit_saml_authn_request_url(overrides: saml_overrides)
  end

  def visit_idp_from_oidc_sp_with_ial2(
    client_id: sp_oidc_issuer,
    state: SecureRandom.hex,
    nonce: SecureRandom.hex,
    verified_within: nil
  )
    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email profile:name phone social_security_number',
      redirect_uri: sp_oidc_redirect_uri,
      state: state,
      prompt: 'select_account',
      nonce: nonce,
      verified_within: verified_within,
    )
  end

  def visit_idp_from_oidc_sp_with_loa3
    visit openid_connect_authorize_path(
      client_id: sp_oidc_issuer,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email profile:name phone social_security_number',
      redirect_uri: sp_oidc_redirect_uri,
      state: SecureRandom.hex,
      prompt: 'select_account',
      nonce: SecureRandom.hex,
    )
  end

  def visit_idp_from_saml_sp_with_loa3
    saml_overrides = {
      issuer: sp1_issuer,
      authn_context: [
        Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
        "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
        "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
      ],
      security: {
        embed_sign: false,
      },
    }
    if javascript_enabled?
      idp_domain_name = "#{page.server.host}:#{page.server.port}"
      saml_overrides[:idp_sso_target_url] = "http://#{idp_domain_name}/api/saml/auth"
      saml_overrides[:idp_slo_target_url] = "http://#{idp_domain_name}/api/saml/logout"
    end
    visit_saml_authn_request_url(overrides: saml_overrides)
  end
end
