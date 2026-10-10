require 'rails_helper'

RSpec.describe DelegatedAccessEvents do
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
  let(:user) { create(:user, :proofed) }
  let(:grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: housing,
      source: 'account_page', remember: true
    )
  end
  let(:redis_client) { AttemptsApi::RedisClient.new }
  let(:allowed_attempts_providers) { [{ 'issuer' => housing.issuer, 'keys' => [] }] }

  before do
    allow(IdentityConfig.store).to receive_messages(
      attempts_api_enabled: true,
      token_exchange_enabled: true,
      token_exchange_attempts_delivery_enabled: true,
      allowed_attempts_providers:,
    )
  end

  def housing_events
    redis_client.read_events(issuer: housing.issuer).values.map do |jwe|
      AttemptsApi::AttemptEvent.from_jwe(jwe, saml_test_sp_private_key)
    end
  end

  def housing_identity
    AgencyIdentity.find_by(user:, agency: housing.agency)
  end

  describe '.enabled?' do
    it 'requires delegated access, this delivery and the Attempts API all to be on' do
      expect(described_class.enabled?).to eq(true)

      %i[token_exchange_enabled token_exchange_attempts_delivery_enabled attempts_api_enabled]
        .each do |switch|
          allow(IdentityConfig.store).to receive(switch).and_return(false)
          expect(described_class.enabled?).to eq(false)
          allow(IdentityConfig.store).to receive(switch).and_return(true)
        end
    end
  end

  describe '.consented' do
    it 'writes the consent event to the application, attributed to the agency identifier' do
      freeze_time do
        events = described_class.consented(grant, remembered: true)

        expect(events.map(&:event_type)).to eq(['delegated-access-consented'])
        stored = housing_events.first
        expect(stored.session_id).to be_nil
        expect(stored.event_metadata).to include(
          user_uuid: housing_identity.uuid,
          delegation_id: grant.delegation_id,
          actor_issuer: mybenefits.issuer,
          application: housing.issuer,
          scope: 'token_exchange:housing_records',
          remembered: true,
          source: 'account_page',
          consented_at: grant.consented_at.to_f,
        )
        expect(stored.event_metadata).not_to have_key(:user_ip_address)
        expect(ServiceProviderIdentity.where(user:, service_provider: housing.issuer)).to be_empty
      end
    end

    it 'creates the agency identifier for a person the agency has never seen, and reuses it' do
      expect(housing_identity).to be_nil
      described_class.consented(grant, remembered: false)
      first = housing_identity
      expect(first).to be_present
      described_class.consented(grant, remembered: true)
      expect(AgencyIdentity.where(user:, agency: housing.agency).count).to eq(1)
      expect(housing_events.map { |e| e.event_metadata[:user_uuid] }.uniq).to eq([first.uuid])
    end

    it 'logs the outcome for the person when no analytics are given' do
      expect_any_instance_of(Analytics).to receive(:delegated_access_attempts_delivery).with(
        hash_including(
          event_type: 'delegated-access-consented', recipient_issuer: housing.issuer,
          actor_issuer: mybenefits.issuer, success: true, event_count: 1
        ),
      )
      described_class.consented(grant, remembered: false)
    end
  end

  describe 'token events' do
    let!(:housing_api) do
      create(
        :token_exchange_resource_server, service_provider: housing,
                                         identifier: 'https://records-api.housing.example.gov'
      )
    end
    let(:issued) do
      create(
        :token_exchange_token, grant:, resource_server: housing_api, ial: 2, aal: 2,
                               token_type: 'DPoP', expires_at: 15.minutes.from_now
      )
    end

    before { user.update!(unique_session_id: 'idp-session-1') }

    it 'writes token-issued for the API with the join keys and no network details' do
      freeze_time do
        event = described_class.token_issued(issued)

        expect(event.event_type).to eq('delegated-access-token-issued')
        expect(event.session_id).to be_nil
        expect(event.event_metadata).to include(
          user_uuid: housing_identity.uuid,
          delegation_id: grant.delegation_id,
          actor_issuer: mybenefits.issuer,
          application: housing.issuer,
          resource: 'https://records-api.housing.example.gov',
          scope: 'token_exchange:housing_records',
          ial: 2,
          aal: 2,
          token_type: 'DPoP',
          token_format: 'oauth',
          expires_at: 15.minutes.from_now.to_i,
          unique_session_id: Digest::SHA1.hexdigest('idp-session-1'),
        )
        %i[user_ip_address user_agent client_port device_id google_analytics_cookies].each do |key|
          expect(event.event_metadata).not_to have_key(key)
        end
        expect(event.event_metadata.values.map(&:to_s).join).not_to include('idp-session-1')
        expect(housing_events.map(&:event_type)).to eq(['delegated-access-token-issued'])
      end
    end

    it 'writes token-refreshed the same way' do
      event = described_class.token_refreshed(issued)

      expect(event.event_type).to eq('delegated-access-token-refreshed')
      expect(event.event_metadata).to include(
        delegation_id: grant.delegation_id, resource: housing_api.identifier, token_type: 'DPoP',
      )
    end

    it 'writes the event to the recipient the API names in place of the application' do
      records_office = create(:service_provider)
      housing_api.update!(attempts_service_provider: records_office)
      allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
        [{ 'issuer' => records_office.issuer, 'keys' => [] }],
      )

      described_class.token_issued(issued)

      expect(redis_client.read_events(issuer: records_office.issuer).size).to eq(1)
      expect(redis_client.read_events(issuer: housing.issuer)).to be_empty
      expect(AgencyIdentity.find_by(user:, agency: records_office.agency)).to be_present
    end

    it 'omits the session hash when the person has no live session' do
      user.update!(unique_session_id: nil)
      event = described_class.token_issued(issued)
      expect(event.event_metadata).not_to have_key(:unique_session_id)
    end
  end

  describe '.access_revoked' do
    it 'tells every recipient of the application why access ended' do
      events = described_class.access_revoked(grant:, reason: 'user_revoked')

      expect(events.map(&:event_type)).to eq(['delegated-access-revoked'])
      expect(events.first.event_metadata).to include(
        user_uuid: housing_identity.uuid,
        delegation_id: grant.delegation_id,
        actor_issuer: mybenefits.issuer,
        application: housing.issuer,
        resource: nil,
        reason: 'user_revoked',
      )
      expect(housing_events.map(&:event_type)).to eq(['delegated-access-revoked'])
    end

    it 'names the API when only one refresh family ended' do
      housing_api = create(:token_exchange_resource_server, service_provider: housing)
      other_api = create(
        :token_exchange_resource_server, service_provider: housing,
                                         attempts_service_provider: create(:service_provider)
      )

      events = described_class.access_revoked(
        grant:, reason: 'refresh_token_reuse', resource_server: housing_api,
      )

      expect(events.size).to eq(1)
      expect(events.first.event_metadata).to include(
        reason: 'refresh_token_reuse', resource: housing_api.identifier,
      )
      expect(redis_client.read_events(issuer: other_api.attempts_recipient.issuer)).to be_empty
    end

    it 'does not report a superseding re-approval' do
      expect(described_class.access_revoked(grant:, reason: 'superseded_by_new_consent')).to eq([])
      expect(redis_client.read_events(issuer: housing.issuer)).to be_empty
    end
  end

  context 'when the recipient is not enrolled in the Attempts API' do
    let(:allowed_attempts_providers) { [] }

    it 'writes nothing and creates no identifier' do
      expect(described_class.consented(grant, remembered: false)).to eq([])
      expect(redis_client.read_events(issuer: housing.issuer)).to be_empty
      expect(housing_identity).to be_nil
    end
  end

  context 'when the recipient is listed without a usable encryption key' do
    let(:housing) { create(:service_provider, :delegation_application, certs: []) }

    it 'writes nothing and creates no identifier' do
      expect(described_class.consented(grant, remembered: false)).to eq([])
      expect(housing_identity).to be_nil
    end
  end

  context 'when delivery to agencies is switched off' do
    before do
      allow(IdentityConfig.store).to receive(:token_exchange_attempts_delivery_enabled)
        .and_return(false)
    end

    it 'writes nothing and creates no identifier' do
      expect(described_class.consented(grant, remembered: false)).to eq([])
      expect(redis_client.read_events(issuer: housing.issuer)).to be_empty
      expect(housing_identity).to be_nil
    end
  end
end
