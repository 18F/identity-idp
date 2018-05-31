module IdvHelper
  def self.included(base)
    base.class_eval { include JavascriptDriverHelper }
  end

  def max_attempts_less_one
    Idv::Attempter.idv_max_attempts - 1
  end

  def user_password
    Features::SessionHelper::VALID_PASSWORD
  end

  def fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'José'
    fill_in 'profile_last_name', with: 'One'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Virginia', from: 'profile_state'
    fill_in 'profile_zipcode', with: '66044'
    fill_in 'profile_dob', with: '01/02/1980'
    fill_in 'profile_ssn', with: '666-66-1234'
    find("label[for='profile_state_id_type_drivers_permit']").click
    fill_in 'profile_state_id_number', with: '123456789'
  end

  def fill_out_idv_form_fail(state: 'Virginia')
    fill_in 'profile_first_name', with: 'Bad'
    fill_in 'profile_last_name', with: 'User'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select state, from: 'profile_state'
    fill_in 'profile_zipcode', with: '00000'
    fill_in 'profile_dob', with: '01/02/1900'
    fill_in 'profile_ssn', with: '666-66-6666'
    find("label[for='profile_state_id_type_drivers_permit']").click
    fill_in 'profile_state_id_number', with: '123456789'
  end

  def fill_out_idv_jurisdiction_ok
    select 'Washington', from: 'jurisdiction_state'
    expect(page).to have_no_content t('idv.errors.unsupported_jurisdiction')
  end

  def fill_out_idv_state_fail
    select 'Alabama', from: 'profile_state'
    expect(page).to have_content t('idv.errors.unsupported_jurisdiction')
  end

  def fill_out_idv_state_ok
    select 'California', from: 'profile_state'
    expect(page).to have_no_content t('idv.errors.unsupported_jurisdiction')
  end

  def fill_out_phone_form_ok(phone = '415-555-0199')
    fill_in :idv_phone_form_phone, with: phone
  end

  def fill_out_phone_form_fail
    fill_in :idv_phone_form_phone, with: '(555) 555-5555'
  end

  def click_idv_continue
    click_on t('forms.buttons.continue')
  end

  def click_idv_address_choose_phone
    # we're capturing the click on the label element via the unique "for" attribute
    # which matches against the radio button's ID,
    # so that we can capture any click within the label.
    find("label[for='address_delivery_method_phone']").click
    click_on t('forms.buttons.continue')
  end

  def click_idv_address_choose_usps
    # we're capturing the click on the label element via the unique "for" attribute
    # which matches against the radio button's ID,
    # so that we can capture any click within the label.
    find("label[for='address_delivery_method_usps']").click
    click_on t('forms.buttons.continue')
  end

  def choose_idv_otp_delivery_method_sms
    using_wait_time(5) do
      click_on t('idv.buttons.send_confirmation_code')
    end
  end

  def choose_idv_otp_delivery_method_voice
    page.find(
      'label',
      text: t('devise.two_factor_authentication.otp_delivery_preference.voice')
    ).click
    click_on t('idv.buttons.send_confirmation_code')
  end

  def click_idv_cancel_modal
    within('.modal') do
      click_on t('idv.buttons.cancel')
    end
  end

  def click_idv_cancel
    click_on t('idv.buttons.cancel')
  end

  def complete_idv_profile_ok(user, password = user_password)
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_continue
    click_idv_address_choose_phone
    click_idv_continue
    fill_in 'Password', with: password
    click_continue
  end

  def visit_idp_from_sp_with_loa3(sp)
    if sp == :saml
      settings = loa3_with_bundle_saml_settings
      settings.security[:embed_sign] = false
      if javascript_enabled?
        idp_domain_name = "#{page.server.host}:#{page.server.port}"
        settings.idp_sso_target_url = "http://#{idp_domain_name}/api/saml/auth"
        settings.idp_slo_target_url = "http://#{idp_domain_name}/api/saml/logout"
      end
      @saml_authn_request = auth_request.create(settings)
      visit @saml_authn_request
    elsif sp == :oidc
      @state = SecureRandom.hex
      @client_id = 'urn:gov:gsa:openidconnect:sp:server'
      @nonce = SecureRandom.hex
      visit_idp_from_oidc_sp_with_loa3(state: @state, client_id: @client_id, nonce: @nonce)
    end
  end

  def visit_idp_from_oidc_sp_with_loa3(state: SecureRandom.hex, client_id:, nonce:)
    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email profile:name phone social_security_number',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce
    )
  end
end
