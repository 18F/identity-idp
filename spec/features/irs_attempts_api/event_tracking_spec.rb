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
    freeze_time do
      user = create(:user, :signed_up)

      visit_idp_from_ial1_oidc_sp(
        client_id: service_provider.issuer,
        irs_attempts_api_session_id: 'test-session-id',
      )

      sign_in_user(user)

      events = irs_attempts_api_tracked_events(timestamp: Time.zone.now)
      expected_event_types = %w[email-and-password-auth mfa-login-phone-otp-sent]

      received_event_types = events.map(&:event_type)

      expect(events.count).to eq received_event_types.count
      expect(received_event_types).to match_array(expected_event_types)

      metadata = events.first.event_metadata
      expect(metadata[:user_ip_address]).to eq '127.0.0.1'
      expect(metadata[:irs_application_url]).to eq 'http://localhost:7654/auth/result'
      expect(metadata[:unique_session_id]).to be_a(String)
      expect(metadata[:success]).to be_truthy
    end
  end

  scenario 'signing in from an IRS SP without an attempts api session id does not track events' do
    freeze_time do
      user = create(:user, :signed_up)

      visit_idp_from_ial1_oidc_sp(
        client_id: service_provider.issuer,
      )

      sign_in_user(user)

      events = irs_attempts_api_tracked_events(timestamp: Time.zone.now)

      expect(events.count).to eq(0)
    end
  end

  scenario 'signing in from a non-IRS SP with an attempts api session id does not track events' do
    freeze_time do
      service_provider.update!(irs_attempts_api_enabled: false)

      user = create(:user, :signed_up)

      visit_idp_from_ial1_oidc_sp(
        client_id: service_provider.issuer,
        irs_attempts_api_session_id: 'test-session_id',
      )

      sign_in_user(user)

      events = irs_attempts_api_tracked_events(timestamp: Time.zone.now)

      expect(events.count).to eq(0)
    end
  end
end
