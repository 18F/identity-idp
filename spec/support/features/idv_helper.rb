module IdvHelper
  def max_attempts_less_one
    Idv::Attempter.idv_max_attempts - 1
  end

  def user_password
    Features::SessionHelper::VALID_PASSWORD
  end

  def fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'José'
    fill_in 'profile_last_name', with: 'One'
    fill_in 'profile_ssn', with: '666-66-1234'
    fill_in 'profile_dob', with: '01/02/1980'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Kansas', from: 'profile_state'
    fill_in 'profile_zipcode', with: '66044'
  end

  def fill_out_idv_form_fail
    fill_in 'profile_first_name', with: 'Bad'
    fill_in 'profile_last_name', with: 'User'
    fill_in 'profile_ssn', with: '666-66-6666'
    fill_in 'profile_dob', with: '01/02/1900'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Kansas', from: 'profile_state'
    fill_in 'profile_zipcode', with: '00000'
  end

  def fill_out_idv_previous_address_ok
    fill_in 'profile_prev_address1', with: '456 Other Ave'
    fill_in 'profile_prev_city', with: 'Elsewhere'
    select 'Missouri', from: 'profile_prev_state'
    fill_in 'profile_prev_zipcode', with: '64000'
  end

  def fill_out_idv_previous_address_fail
    fill_in 'profile_prev_address1', with: '456 Other Ave'
    fill_in 'profile_prev_city', with: 'Elsewhere'
    select 'Missouri', from: 'profile_prev_state'
    fill_in 'profile_prev_zipcode', with: '00000'
  end

  def fill_out_phone_form_ok(phone = '415-555-0199')
    fill_in :idv_phone_form_phone, with: phone
  end

  def fill_out_phone_form_fail
    fill_in :idv_phone_form_phone, with: '(555) 555-5555'
  end

  def click_idv_begin
    click_on t('idv.index.continue_link')
  end

  def click_idv_continue
    click_button t('forms.buttons.continue')
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
    page.find(
      'label',
      text: t('devise.two_factor_authentication.otp_delivery_preference.sms')
    ).click
    click_on t('idv.buttons.send_confirmation_code')
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
    click_idv_address_choose_phone
    fill_out_phone_form_ok(user.phone)
    click_idv_continue
    fill_in 'Password', with: password
    click_submit_default
  end

  def visit_idp_from_sp_with_loa3(sp)
    if sp == :saml
      @saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
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
