# frozen_string_literal: true

require_relative '../../lib/saml_idp_constants'

Given('I have cucumber setup correctly') do
  @user = FactoryBot.create(
    :user, :fully_registered, with: { phone: '+1 202-555-1212' },
                              password: 'Val!d Pass w0rd'
  )
  @service_provider = FactoryBot.create(:service_provider, :active, :in_person_proofing_enabled)

  visit_idp_from_sp_with_ial2(:oidc, **{ client_id: @service_provider.issuer })
  sign_in_via_branded_page(@user)
end

When('I run cucumber') do
end

Then('This should pass') do
  expect(true).to be(false)
end

def visit_idp_from_sp_with_ial2(sp, **extra)
  if sp == :saml
    visit_idp_from_saml_sp_with_ial2
  elsif sp == :oidc
    @state = SecureRandom.hex
    @nonce = SecureRandom.hex
    @client_id = 'urn:gov:gsa:openidconnect:sp:server'
    visit_idp_from_oidc_sp_with_ial2(state: @state, client_id: @client_id, nonce: @nonce, **extra)
  end
end

def visit_idp_from_oidc_sp_with_ial2(
  client_id: 'urn:gov:gsa:openidconnect:sp:server',
  state: SecureRandom.hex,
  nonce: SecureRandom.hex,
  verified_within: nil,
  facial_match_required: nil
)
  params = {
    client_id:,
    response_type: 'code',
    scope: 'openid email profile:name phone social_security_number',
    redirect_uri: 'http://localhost:7654/auth/result',
    state:,
    prompt: 'select_account',
    nonce:,
    verified_within:,
  }

  if facial_match_required
    params[:acr_values] = Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR
  else
    params[:acr_values] = Saml::Idp::Constants::IAL_VERIFIED_ACR
  end

  visit openid_connect_authorize_path(params)
end

def sign_in_via_branded_page(user)
  fill_in_credentials_and_submit(user.confirmed_email_addresses.first.email, user.password)
  fill_in_code_with_last_phone_otp
  click_submit_default
end

def fill_in_credentials_and_submit(email, password)
  fill_in I18n.t('account.index.email'), with: email
  fill_in I18n.t('account.index.password'), with: password
  click_button I18n.t('links.sign_in')
end

def fill_in_code_with_last_phone_otp
  accept_rules_of_use_and_continue_if_displayed
  fill_in I18n.t('components.one_time_code_input.label'), with: last_phone_otp
end

def accept_rules_of_use_and_continue_if_displayed
  return unless current_path == rules_of_use_path
  check 'rules_of_use_form[terms_accepted]'
  click_button I18n.t('forms.buttons.continue')
end

def last_phone_otp
  [
    Telephony::Test::Message.messages,
    Telephony::Test::Call.calls,
  ].flatten.compact.sort_by(&:sent_at).reverse_each do |message_or_call|
    otp = message_or_call.otp
    return otp if otp.present?
  end
  nil
end
