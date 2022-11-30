require 'rails_helper'

RSpec.describe ServiceProviderIdentity do
  let(:user) { create(:user, :signed_up) }
  let(:identity) do
    ServiceProviderIdentity.create(
      user_id: user.id,
      service_provider: 'externalapp',
      last_consented_at: Time.zone.now,
    )
  end

  subject { identity }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:service_provider) }

  describe '.deactivate' do
    let(:active_identity) { create(:service_provider_identity, :active) }

    it 'sets last_authenticated_at to nil' do
      active_identity.deactivate
      expect(identity.last_authenticated_at).to be_nil
    end
  end

  # maw: It's not customary to test scopes and this should probably go away.
  # Just using this while I work to prove that nothing silly is happening.
  describe '.consented scope' do
    let!(:consented_user) { create(:service_provider_identity) }
    let!(:non_consented_user) { create(:service_provider_identity, :non_consented) }

    subject { described_class.consented }

    it 'includes users with last_consented_at set' do
      expect(subject).to include(consented_user)
    end

    it 'excludes users without last_consented_at set' do
      expect(subject).to_not include(non_consented_user)
    end
  end

  describe 'uuid validations' do
    it 'uses a DB constraint to enforce presence' do
      identity = create(:service_provider_identity)
      identity.uuid = nil

      expect { identity.save }.
        to raise_error(
          ActiveRecord::NotNullViolation,
          /null value in column "uuid".*violates not-null constraint/,
        )
    end

    it 'uses a DB index to enforce uniqueness' do
      identity1 = create(:service_provider_identity)
      identity1.save
      identity2 = create(:service_provider_identity)
      identity2.uuid = identity1.uuid

      expect { identity2.save }.
        to raise_error(
          ActiveRecord::StatementInvalid,
          /duplicate key value violates unique constraint/,
        )
    end
  end

  describe '#generate_uuid' do
    it 'calls generate_uuid before creation' do
      identity = build(:service_provider_identity, uuid: 'foo')

      expect(identity).to receive(:generate_uuid)

      identity.save
    end

    context 'when already has a uuid' do
      it 'returns the current uuid' do
        identity = create(:service_provider_identity)
        old_uuid = identity.uuid

        expect(identity.generate_uuid).to eq old_uuid
      end
    end

    context 'when does not already have a uuid' do
      it 'generates it via SecureRandom.uuid' do
        identity = build(:service_provider_identity)

        expect(identity.generate_uuid).
          to match(/[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}/)
      end
    end
  end

  let(:service_provider) do
    create(:service_provider)
  end

  let(:identity_with_sp) do
    ServiceProviderIdentity.create(
      user_id: user.id,
      service_provider: service_provider.issuer,
    )
  end

  describe '#display_name' do
    it 'returns service provider friendly name first' do
      expect(identity_with_sp.display_name).to eq(service_provider.friendly_name)
    end

    it 'returns service_provider friendly_name if agency is missing' do
      service_provider.friendly_name = 'Only Friendly Name'
      service_provider.agency = nil
      service_provider.save
      expect(identity_with_sp.display_name).to eq(service_provider.friendly_name)
    end
  end

  describe '#agency_name' do
    it 'returns service provider agency first' do
      expect(identity_with_sp.agency_name).to eq(service_provider.agency.name)
    end

    it 'returns service_provider friendly_name if agency is missing' do
      service_provider.agency = nil
      service_provider.save
      expect(identity_with_sp.agency_name).to eq(service_provider.friendly_name)
    end

    it 'returns service_provider friendly_name if agency is missing' do
      service_provider.friendly_name = 'Only Friendly Name'
      service_provider.agency = nil
      service_provider.save
      expect(identity_with_sp.agency_name).to eq(service_provider.friendly_name)
    end
  end

  describe 'uniqueness validation for service provider per user' do
    it 'raises an error when uniqueness constraint is broken' do
      ServiceProviderIdentity.create(user_id: user.id, service_provider: 'externalapp')
      expect { ServiceProviderIdentity.create(user_id: user.id, service_provider: 'externalapp') }.
        to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'does not raise an error for a different service provider' do
      ServiceProviderIdentity.create(user_id: user.id, service_provider: 'externalapp')
      expect { ServiceProviderIdentity.create(user_id: user.id, service_provider: 'externalapp2') }.
        to_not raise_error
    end
  end

  describe '#return_to_sp_url' do
    let(:user) { create(:user) }
    let(:service_provider) { 'http://localhost:3000' }
    let(:identity) do
      create(:service_provider_identity, :active, user: user, service_provider: service_provider)
    end

    context 'for an sp with a return URL' do
      it 'returns the return url for the sp' do
        return_to_sp_url = ServiceProvider.find_by(issuer: service_provider).return_to_sp_url
        expect(subject.return_to_sp_url).to eq(return_to_sp_url)
      end
    end

    context 'for an sp without a return URL' do
      let(:service_provider) { 'https://rp2.serviceprovider.com/auth/saml/metadata' }

      it 'returns nil' do
        expect(subject.return_to_sp_url).to eq(nil)
      end
    end
  end

  describe '#failure_to_proof_url' do
    let(:user) { create(:user) }
    let(:service_provider) { 'https://rp1.serviceprovider.com/auth/saml/metadata' }
    let(:identity) do
      create(:service_provider_identity, :active, user: user, service_provider: service_provider)
    end

    context 'for an sp with a failure to proof url' do
      it 'returns the failure_to_proof_url for the sp' do
        failure_to_proof_url = ServiceProvider.find_by(
          issuer: service_provider,
        ).failure_to_proof_url
        expect(subject.failure_to_proof_url).to eq(failure_to_proof_url)
      end
    end

    context 'for an sp without a failure to proof URL' do
      let(:service_provider) { 'http://localhost:3000' }

      it 'returns nil' do
        expect(subject.failure_to_proof_url).to eq(nil)
      end
    end
  end
end
