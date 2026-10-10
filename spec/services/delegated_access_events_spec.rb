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
