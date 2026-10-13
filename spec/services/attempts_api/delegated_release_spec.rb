require 'rails_helper'

# MyBenefits Assistant (Office of Benefits Coordination) signs the person in and asks to act at
# Housing Assistance Records (Department of Housing Support) and Retirement Benefits Portal
# (National Retirement Administration); the person approves Housing only.
RSpec.describe AttemptsApi::DelegatedRelease do
  let(:mybenefits) do
    create(
      :service_provider, :delegation_service_provider,
      issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits'
    )
  end
  let(:housing) do
    create(
      :service_provider, :delegation_application,
      issuer: 'urn:gov:gsa:openidconnect:sp:housing_records',
      delegation_scope_value: 'housing_records'
    )
  end
  let(:retirement) do
    create(
      :service_provider, :delegation_application,
      issuer: 'urn:gov:gsa:openidconnect:sp:retirement_benefits',
      delegation_scope_value: 'retirement_benefits'
    )
  end
  let!(:housing_api) { create(:token_exchange_resource_server, service_provider: housing) }
  let(:profile) { create(:profile, :active, :verified, encrypted_attempts_file_reference: 'ref') }
  let(:user) { profile.user }
  let(:housing_grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: housing,
      source: 'consent_screen', remember: false, rails_session_id: 'sess-1'
    )
  end
  let(:session) { {} }
  let(:user_session) { {} }
  let(:analytics) { FakeAnalytics.new }
  let(:context) { AttemptsApi::DelegationContext.from_session(session) }
  let(:redis_client) { AttemptsApi::RedisClient.new }
  let(:request_id) { 'req-1' }
  let(:allowed_attempts_providers) do
    [
      { 'issuer' => housing.issuer, 'keys' => [] },
      { 'issuer' => retirement.issuer, 'keys' => [] },
    ]
  end

  let(:buffered_event) do
    AttemptsApi::AttemptEvent.new(
      event_type: 'mfa-login-auth-submitted',
      session_id: 'sp-session-id',
      occurred_at: Time.zone.now,
      event_metadata: {
        user_uuid: 'sp-uuid',
        google_analytics_cookies: { '_ga' => 'x' },
        user_ip_address: '192.0.2.1',
        application_url: 'https://mybenefits.example.gov/return',
        mfa_device_type: 'phone',
        success: true,
      },
    )
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      attempts_api_enabled: true,
      historical_attempts_api_enabled: true,
      token_exchange_enabled: true,
      token_exchange_attempts_delivery_enabled: true,
      allowed_attempts_providers:,
    )
    context.start(
      request_id:, sp_issuer: mybenefits.issuer,
      candidate_issuers: [housing.issuer, retirement.issuer]
    )
    context.push_buffered_event(buffered_event)
  end

  def agency_events(issuer)
    redis_client.read_events(issuer:).values.map do |jwe|
      AttemptsApi::AttemptEvent.from_jwe(jwe, saml_test_sp_private_key)
    end
  end

  def agency_identity(application)
    AgencyIdentity.find_by(user:, agency: application.agency)
  end

  subject(:release) do
    described_class.new(
      user:, session:, user_session:, analytics:, grants: [housing_grant], request_id:,
    )
  end

  it 'delivers the buffer and the consent event to the approved application only' do
    freeze_time do
      release.call

      events = agency_events(housing.issuer)
      expect(events.map(&:event_type)).to match_array(
        ['mfa-login-auth-submitted', 'delegated-access-consented'],
      )

      remapped = events.find { |e| e.event_type == 'mfa-login-auth-submitted' }
      expect(remapped.session_id).to eq('sp-session-id')
      expect(remapped.event_metadata).to include(
        user_uuid: agency_identity(housing).uuid,
        delegation_id: housing_grant.delegation_id,
        actor_issuer: mybenefits.issuer,
        user_ip_address: '192.0.2.1',
        application_url: 'https://mybenefits.example.gov/return',
        mfa_device_type: 'phone',
      )
      expect(remapped.event_metadata).not_to have_key(:google_analytics_cookies)

      consented = events.find { |e| e.event_type == 'delegated-access-consented' }
      expect(consented.event_metadata).to include(
        user_uuid: agency_identity(housing).uuid,
        delegation_id: housing_grant.delegation_id,
        actor_issuer: mybenefits.issuer,
        application: housing.issuer,
        scope: 'token_exchange:housing_records',
        remembered: false,
        source: 'consent_screen',
        consented_at: housing_grant.consented_at.to_f,
      )

      expect(agency_events(retirement.issuer)).to be_empty
      expect(agency_identity(retirement)).to be_nil
      expect(ServiceProviderIdentity.where(user:)).to be_empty
    end
  end

  it 'marks the recipient approved, the buffer delivered and the request released' do
    release.call

    expect(context.approved_issuers).to eq([housing.issuer])
    expect(context.approved[housing.issuer]).to eq(
      'delegation_id' => housing_grant.delegation_id,
      'agency_uuid' => agency_identity(housing).uuid,
    )
    expect(context.buffer_delivered_to?(housing.issuer)).to eq(true)
    expect(context.released_for?(request_id)).to eq(true)
  end

  it 'does not deliver the buffer twice to the same recipient, and reports a reuse as remembered' do
    release.call
    described_class.new(
      user:, session:, user_session:, analytics:, remembered_grants: [housing_grant],
      request_id: 'req-2'
    ).call

    events = agency_events(housing.issuer)
    expect(events.count { |e| e.event_type == 'mfa-login-auth-submitted' }).to eq(1)
    consented = events.select { |e| e.event_type == 'delegated-access-consented' }
    expect(consented.map { |e| e.event_metadata[:remembered] }).to match_array([false, true])
    expect(context.released_for?('req-2')).to eq(true)
  end

  it 'delivers to the recipient an API names in place of the application' do
    records_office = create(
      :service_provider,
      issuer: 'urn:gov:gsa:openidconnect:sp:records_office',
    )
    housing_api.update!(attempts_service_provider: records_office)
    allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
      [{ 'issuer' => records_office.issuer, 'keys' => [] }],
    )

    release.call

    expect(agency_events(records_office.issuer).map(&:event_type)).to match_array(
      ['mfa-login-auth-submitted', 'delegated-access-consented'],
    )
    expect(agency_events(housing.issuer)).to be_empty
    expect(context.approved_issuers).to eq([records_office.issuer])
  end

  context 'when the approval is for another service provider than the one signing in' do
    let(:other_sp) { create(:service_provider, :delegation_service_provider) }
    let(:account_page_grant) do
      TokenExchangeGrant.approve!(
        user:, service_provider: other_sp, application: housing,
        source: 'account_page', remember: true
      )
    end

    it 'writes the consent event but does not forward this session to the agency' do
      described_class.new(
        user:, session:, user_session:, analytics:, grants: [account_page_grant],
      ).call

      consented = agency_events(housing.issuer).find do |e|
        e.event_type == 'delegated-access-consented'
      end
      expect(consented.event_metadata).to include(
        actor_issuer: other_sp.issuer, source: 'account_page', remembered: false,
      )
      expect(context.approved).to eq({})
      expect(context.released_for?(request_id)).to eq(false)
    end
  end

  it 'treats a recipient listed in the Attempts configuration without a key as not enrolled' do
    housing.update!(certs: [])

    expect { release.call }.not_to raise_error
    expect(redis_client.read_events(issuer: housing.issuer)).to be_empty
    expect(agency_identity(housing)).to be_nil
    expect(context.approved).to eq({})
    expect(context.released_for?(request_id)).to eq(true)
  end

  it 'delivers nothing and creates no identifier when the recipient is not enrolled' do
    allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return([])
    release.call
    expect(redis_client.read_events(issuer: housing.issuer)).to be_empty
    expect(agency_identity(housing)).to be_nil
    expect(context.approved).to eq({})
  end

  it 'does nothing while delivery to agencies is switched off' do
    allow(IdentityConfig.store).to receive(:token_exchange_attempts_delivery_enabled)
      .and_return(false)
    release.call
    expect(redis_client.read_events(issuer: housing.issuer)).to be_empty
    expect(agency_identity(housing)).to be_nil
    expect(context.released_for?(request_id)).to eq(false)
  end

  it 'never raises out of a failing release and reports it' do
    allow(AgencyIdentityLinker).to receive(:for).and_raise(ActiveRecord::StatementInvalid, 'down')
    expect(NewRelic::Agent).to receive(:notice_error).with(
      kind_of(ActiveRecord::StatementInvalid),
      custom_params: { recipient_issuer: housing.issuer, step: 'delegated_release' },
    )

    expect { release.call }.not_to raise_error

    expect(analytics).to have_logged_event(
      :delegated_access_attempts_delivery,
      hash_including(
        event_type: 'delegated_release', recipient_issuer: housing.issuer, success: false,
        exception: 'ActiveRecord::StatementInvalid'
      ),
    )
    expect(context.released_for?(request_id)).to eq(true)
  end

  describe 'identity-proofing history' do
    let(:idv_attempts) do
      [
        {
          'jti' => SecureRandom.uuid,
          'iat' => Time.zone.now.to_i,
          'event_type' => 'idv-ssn-submitted',
          'session_id' => nil,
          'occurred_at' => Time.zone.now.iso8601,
          'event_metadata' => { 'user_uuid' => sp_agency_uuid, 'success' => true },
        },
      ]
    end
    let(:sp_agency_uuid) do
      AgencyIdentityLinker.for(user:, service_provider: mybenefits, skip_create: false).uuid
    end

    before { profile.create_user_proofing_event!(service_provider_ids_sent: []) }

    context 'when the history is in the session' do
      before do
        user_session[:encrypted_proofing_events] =
          SessionEncryptor.new.kms_encrypt(idv_attempts.to_json)
      end

      it 'releases it once to the agency with the join keys' do
        release.call
        released = agency_events(housing.issuer).select { |e| e.event_type == 'idv-ssn-submitted' }
        expect(released.length).to eq(1)
        expect(released.first.event_metadata).to include(
          user_uuid: agency_identity(housing).uuid,
          delegation_id: housing_grant.delegation_id,
          actor_issuer: mybenefits.issuer,
        )
        expect(profile.user_proofing_event.reload.already_sent_to_sp?(housing.id)).to eq(true)
        expect(analytics).to have_logged_event(
          :delegated_access_attempts_delivery,
          hash_including(event_type: 'historical_proofing_events', success: true, event_count: 1),
        )

        described_class.new(
          user:, session:, user_session:, analytics:, remembered_grants: [housing_grant],
          request_id: 'req-2'
        ).call
        released = agency_events(housing.issuer).select { |e| e.event_type == 'idv-ssn-submitted' }
        expect(released.length).to eq(1)
      end
    end

    context 'when the history is not in the session' do
      it 'releases nothing and leaves the once-only flag unset' do
        release.call
        expect(agency_events(housing.issuer).map(&:event_type))
          .not_to include('idv-ssn-submitted')
        expect(profile.user_proofing_event.reload.already_sent_to_sp?(housing.id)).to eq(false)
      end
    end
  end
end
