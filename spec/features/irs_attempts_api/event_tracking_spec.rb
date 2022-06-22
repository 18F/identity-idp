require 'rails_helper'

feature 'IRS Attempts API Event Tracking' do
  include OidcAuthHelper
  include IrsAttemptsApiTrackingHelper

  before do
    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)
    mock_irs_attempts_api_encryption_key
  end

  let(:service_provider) do
    create(
      :service_provider,
      active: true,
      redirect_uris: ['http://localhost:7654/auth/result'],
      ial: 2,
      irs_attempts_api_enabled: true,
    )
  end

  scenario 'signing in from an IRS SP with an attempts api session id tracks events' do
    user = create(:user, :signed_up)

    visit_idp_from_ial1_oidc_sp(
      client_id: service_provider.issuer,
      irs_attempts_api_session_id: 'test-session-id',
    )

    sign_in_user(user)

    events = irs_attempts_api_tracked_events

    expect(events.count).to eq(1)
    event = events.first
    expect(event.event_metadata[:email]).to eq(user.email)
    expect(event.event_metadata[:success]).to eq(true)
    expect(event.session_id).to eq('test-session-id')
  end

  scenario 'signing in from an IRS SP without an attempts api session id does not track events' do
    user = create(:user, :signed_up)

    visit_idp_from_ial1_oidc_sp(
      client_id: service_provider.issuer,
    )

    sign_in_user(user)

    events = irs_attempts_api_tracked_events

    expect(events.count).to eq(0)
  end

  scenario 'signing in from a non-IRS SP with an attempts api session id does not track events' do
    service_provider.update!(irs_attempts_api_enabled: false)

    user = create(:user, :signed_up)

    visit_idp_from_ial1_oidc_sp(
      client_id: service_provider.issuer,
      irs_attempts_api_session_id: 'test-session_id',
    )

    sign_in_user(user)

    events = irs_attempts_api_tracked_events

    expect(events.count).to eq(0)
  end
end
