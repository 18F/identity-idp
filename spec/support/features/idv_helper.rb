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

  def click_idv_continue_for_step(step)
    if step == :phone
      click_idv_send_security_code
    else
      click_idv_continue
    end
  end

  def click_idv_continue
    click_spinner_button_and_wait t('forms.buttons.continue')
  end

  def click_idv_submit_default
    click_spinner_button_and_wait t('forms.buttons.submit.default')
  end

  def click_idv_update
    click_on t('forms.buttons.submit.update')
  end

  def click_idv_exit
    click_spinner_button_and_wait t('idv.cancel.actions.exit', app_name: APP_NAME)
  end

  def click_idv_send_security_code
    click_spinner_button_and_wait t('forms.buttons.send_one_time_code')
  end

  def click_try_again
    page.find(
      'a',
      text: t('idv.failure.button.warning'),
    ).click
  end

  def click_idv_otp_delivery_method_sms
    page.find(
      'label',
      text: t('two_factor_authentication.otp_delivery_preference.sms'),
      wait: 5,
    ).click
  end

  def choose_idv_otp_delivery_method_sms
    click_idv_otp_delivery_method_sms
    click_idv_send_security_code
  end

  def click_idv_otp_delivery_method_voice
    page.find(
      'label',
      text: t('two_factor_authentication.otp_delivery_preference.voice'),
      wait: 5,
    ).click
  end

  def choose_idv_otp_delivery_method_voice
    click_idv_otp_delivery_method_voice
    click_idv_send_security_code
  end

  def visit_idp_from_sp_with_ial2(sp_type, **extra)
    facial_match_required = extra.delete(:facial_match_required)
    if sp_type == :saml
      if facial_match_required
        visit_idp_from_saml_sp_with_enhanced
      else
        visit_idp_from_saml_sp_with_basic
      end
    elsif sp_type == :oidc
      @state = SecureRandom.hex
      @nonce = SecureRandom.hex
      @client_id = sp_oidc_issuer
      if facial_match_required
        visit_idp_from_oidc_sp_with_enhanced(
          state: @state, client_id: @client_id, nonce: @nonce, **extra,
        )
      else
        visit_idp_from_oidc_sp_with_basic(
          state: @state, client_id: @client_id, nonce: @nonce, **extra,
        )
      end
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

  # IAL2 without facial match (basic verified scope)
  def visit_idp_from_saml_sp_with_basic(issuer: sp1_issuer)
    visit_idp_from_saml_sp_with_authn_context(
      issuer:,
      ial_authn_context: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
    )
  end

  # IAL2 with facial match required (enhanced verified scope)
  def visit_idp_from_saml_sp_with_enhanced(issuer: sp1_issuer)
    visit_idp_from_saml_sp_with_authn_context(
      issuer:,
      ial_authn_context: Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
    )
  end

  def visit_idp_from_saml_sp_with_authn_context(
    issuer: sp1_issuer,
    ial_authn_context: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
  )
    saml_overrides = {
      issuer: issuer,
      authn_context: [
        ial_authn_context,
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

  # IAL2 without facial match (basic verified scope)
  def visit_idp_from_oidc_sp_with_basic(
    client_id: sp_oidc_issuer,
    state: SecureRandom.hex,
    nonce: SecureRandom.hex,
    verified_within: nil
  )
    visit_idp_from_oidc_sp_with_acr_values(
      client_id:,
      state:,
      nonce:,
      verified_within:,
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
    )
  end

  # IAL2 with facial match required (enhanced verified scope)
  def visit_idp_from_oidc_sp_with_enhanced(
    client_id: sp_oidc_issuer,
    state: SecureRandom.hex,
    nonce: SecureRandom.hex,
    verified_within: nil
  )
    visit_idp_from_oidc_sp_with_acr_values(
      client_id:,
      state:,
      nonce:,
      verified_within:,
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
    )
  end

  def visit_idp_from_oidc_sp_with_acr_values(
    client_id: sp_oidc_issuer,
    state: SecureRandom.hex,
    nonce: SecureRandom.hex,
    verified_within: nil,
    acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR
  )
    visit openid_connect_authorize_path(
      client_id:,
      response_type: 'code',
      scope: 'openid email profile:name phone social_security_number',
      redirect_uri: sp_oidc_redirect_uri,
      state:,
      prompt: 'select_account',
      nonce:,
      verified_within:,
      acr_values:,
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

  def validate_idv_completed_page(user)
    expect(user.identity_verified?).to be(true)
    expect(page).to have_current_path sign_up_completed_path
    expect(page).to have_content t(
      'titles.sign_up.completion_idv',
      sp: 'Test SP',
    )
  end

  def validate_return_to_sp
    expect(page).to have_current_path(
      'http://localhost:7654/auth/result',
      url: true,
      ignore_query: true,
    )
  end
end
