require 'rails_helper'

# End-to-end consent for delegated access: a service provider names agency applications with
# token_exchange:* scopes; the person sees them locked on the completion screen and either allows
# them all or cancels back to the service provider; remembered approvals skip the screen next time;
# a material content change brings it back.
RSpec.describe 'Delegated access consent', driver: :desktop_rack_test do
  include OidcAuthHelper

  let(:redirect_uri) { 'http://localhost:7654/auth/result' }
  let(:service_provider) do
    create(
      :service_provider, :delegation_service_provider,
      issuer: 'urn:gov:gsa:openidconnect:sp:consent_feature',
      friendly_name: 'MyBenefits Assistant',
      redirect_uris: [redirect_uri],
      pkce: true
    )
  end
  let(:housing_agency) { create(:agency, name: 'Department of Housing Support') }
  let!(:housing) do
    create(
      :service_provider, :delegation_application, agency: housing_agency,
                                                  delegation_scope_value: 'housing_records',
                                                  delegation_display_name: {
                                                    en: 'Housing Assistance Records',
                                                  }
    )
  end
  let!(:retirement) do
    create(
      :service_provider, :delegation_application,
      agency: create(:agency, name: 'National Retirement Administration'),
      delegation_scope_value: 'retirement_benefits',
      delegation_display_name: { en: 'Retirement Benefits Portal' }
    )
  end
  let(:user) do
    create(
      :user, :proofed, with: { phone: '+1 202-555-1212' },
                       password: Features::SessionHelper::VALID_PASSWORD
    )
  end

  let(:both_scopes) do
    'openid email token_exchange:housing_records token_exchange:retirement_benefits'
  end

  before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true) }

  def authorize(scope:)
    @code_verifier = SecureRandom.hex
    @state = SecureRandom.hex
    visit openid_connect_authorize_path(
      client_id: service_provider.issuer,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
      scope:,
      redirect_uri:,
      state: @state,
      prompt: 'select_account',
      nonce: SecureRandom.hex,
      code_challenge: Digest::SHA256.urlsafe_base64digest(@code_verifier),
      code_challenge_method: 'S256',
    )
  end

  def finish_handoff
    click_submit_default if page.has_button?(t('forms.buttons.submit.default'))
    if page.has_current_path?(user_authorization_confirmation_path)
      click_button t('user_authorization_confirmation.sign_in')
    end
    redirect = if current_path.start_with?('/openid_connect/')
                 URI(oidc_redirect_url)
               else
                 URI(current_url)
               end
    Rack::Utils.parse_query(redirect.query)
  end

  def allow_and_continue(remember: false)
    check 'delegation_remember' if remember
    click_button(t('sign_up.delegation.allow_button'))
  end

  def live_grants
    TokenExchangeGrant.live.where(user:, service_provider_issuer: service_provider.issuer)
  end

  it 'shows every requested application locked, in the agency’s words, and approves them all' do
    authorize(scope: both_scopes)
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(sign_up_completed_path)
    expect(page).to have_content(t('sign_up.delegation.heading', sp: 'MyBenefits Assistant'))
    expect(page).to have_content('Office of Benefits Coordination')
    expect(page).to have_content('Department of Housing Support')
    expect(page).to have_content('Housing Assistance Records')
    expect(page).to have_content('Retirement Benefits Portal')
    expect(page).to have_css(
      "input[name='idv_form[delegation_applications][]'][checked][disabled]", count: 2
    )

    allow_and_continue
    expect(finish_handoff['code']).to be_present

    expect(live_grants.map(&:application)).to contain_exactly(housing, retirement)
    expect(live_grants.pluck(:remember_until).uniq).to eq([nil])
    identity = user.identities.find_by(service_provider: service_provider.issuer)
    expect(identity.verified_attributes).not_to include(a_string_starting_with('token_exchange:'))
  end

  it 'returns the person to the service provider with access_denied when they cancel' do
    authorize(scope: 'openid email token_exchange:housing_records')
    sign_in_live_with_2fa(user)
    expect(page).to have_current_path(sign_up_completed_path)

    click_link t('sign_up.delegation.cancel_button', sp: 'MyBenefits Assistant')

    redirect = URI(current_url)
    params = Rack::Utils.parse_query(redirect.query)
    expect("#{redirect.scheme}://#{redirect.host}:#{redirect.port}#{redirect.path}")
      .to eq(redirect_uri)
    expect(params['error']).to eq('access_denied')
    expect(params['state']).to eq(@state)
    expect(live_grants).to be_empty
  end

  it 'skips the screen for remembered approvals and asks again when the request grows' do
    authorize(scope: 'openid email token_exchange:housing_records')
    sign_in_live_with_2fa(user)
    allow_and_continue(remember: true)
    finish_handoff
    expect(live_grants.first.remember_until).to be_present

    authorize(scope: 'openid email token_exchange:housing_records')
    expect(page).not_to have_current_path(sign_up_completed_path)
    finish_handoff

    authorize(scope: both_scopes)
    expect(page).to have_current_path(sign_up_completed_path)
    expect(page).to have_css('[data-delegation-application][data-status="approved"]', count: 1)
    expect(page).to have_css('[data-delegation-application][data-status="new"]', count: 1)
  end

  it 'asks again, marking the row updated, after a material content change' do
    authorize(scope: 'openid email token_exchange:housing_records')
    sign_in_live_with_2fa(user)
    allow_and_continue(remember: true)
    finish_handoff

    housing.update!(consent_content_version: 2, consent_material_version: 2)
    authorize(scope: 'openid email token_exchange:housing_records')
    expect(page).to have_current_path(sign_up_completed_path)
    expect(page).to have_css('[data-delegation-application][data-status="updated"]', count: 1)
  end

  it 'refuses an unknown application with invalid_scope' do
    authorize(scope: 'openid email token_exchange:not_a_thing')
    params = UriService.params(oidc_redirect_url)
    expect(params[:error]).to eq('invalid_scope')
    expect(params[:error_description]).to include('not_a_thing')
  end
end
