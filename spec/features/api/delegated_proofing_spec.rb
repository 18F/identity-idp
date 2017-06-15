require 'rails_helper'

feature 'Delegated Proofing' do
  include IdvHelper
  include OpenidConnectHelper

  it 'allows accounts to be verified by a participating agency out-of-band', email: true do
    client_id = 'urn:gov:gsa.openidconnect:delegated-proofing'
    state = SecureRandom.hex
    nonce = SecureRandom.hex
    email = 'test@test.com'

    visit_openid_authorize_path(
      client_id: client_id,
      state: state,
      nonce: nonce
    )

    sign_up_with_loa3_data(email: email)

    click_acknowledge_personal_key
    click_on I18n.t('forms.buttons.continue')

    redirect_uri = URI(current_url)
    redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access
    expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    expect(redirect_params[:state]).to eq(state)
    code = redirect_params[:code]
    expect(code).to be_present

    decoded_id_token = load_id_token_data(client_id: client_id, code: code)
    user_id = decoded_id_token[:sub]

    # make sure loa3 attributes are present, but labelled as loa1
    expect(decoded_id_token[:email]).to eq(email)
    expect(decoded_id_token[:given_name]).to eq('José')
    expect(decoded_id_token[:social_security_number]).to eq('666-66-1234')
    expect(decoded_id_token[:acr]).to eq(Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF)

    page.driver.post api_identity_verify_path,
                     user_id: user_id,
                     given_name_matches: true,
                     family_name_matches: true,
                     address_matches: true,
                     birthdate_matches: true,
                     social_security_number_matches: true,
                     phone_matches: true

    expect(page.status_code).to eq(200)

    # user logs in, sees LOA3 verified
    visit account_path
    expect(page).to have_content I18n.t('headings.account.verified_account')
  end

  def visit_openid_authorize_path(client_id:, state:, nonce:)
    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email profile:name social_security_number',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce
    )
  end

  def sign_up_with_loa3_data(email:)
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)

    click_link t('sign_up.registrations.create_account')
    submit_form_with_valid_email
    click_confirmation_link_in_email(email)
    submit_form_with_valid_password
    set_up_2fa_with_valid_phone
    enter_2fa_code
    click_on 'Yes'
    user = User.find_with_email(email)
    complete_idv_profile_ok(user.reload, fill_out_financial: false, fill_out_address: false)
  end

  def load_id_token_data(client_id:, code:)
    jwt_payload = {
      iss: client_id,
      sub: client_id,
      aud: api_openid_connect_token_url,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i,
    }

    client_assertion = JWT.encode(jwt_payload, client_private_key, 'RS256')
    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

    page.driver.post api_openid_connect_token_path,
                     grant_type: 'authorization_code',
                     code: code,
                     client_assertion_type: client_assertion_type,
                     client_assertion: client_assertion

    expect(page.status_code).to eq(200)
    token_response = JSON.parse(page.body).with_indifferent_access

    id_token = token_response[:id_token]
    expect(id_token).to be_present

    decoded_id_token, _headers = JWT.decode(
      id_token, sp_public_key, true, algorithm: 'RS256'
    ).map(&:with_indifferent_access)

    decoded_id_token
  end
end
