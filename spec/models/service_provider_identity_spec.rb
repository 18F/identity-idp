require 'rails_helper'

RSpec.describe ServiceProviderIdentity do
  let(:user) { create(:user, :signed_up) }
  let(:identity) do
    ServiceProviderIdentity.create(
      user_id: user.id,
      service_provider: 'externalapp',
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

  describe 'uuid validations' do
    it 'uses a DB constraint to enforce presence' do
      identity = create(:service_provider_identity)
      identity.uuid = nil

      expect { identity.save }.
        to raise_error(ActiveRecord::NotNullViolation,
                       /null value in column "uuid".*violates not-null constraint/)
    end

    it 'uses a DB index to enforce uniqueness' do
      identity1 = create(:service_provider_identity)
      identity1.save
      identity2 = create(:service_provider_identity)
      identity2.uuid = identity1.uuid

      expect { identity2.save }.
        to raise_error(ActiveRecord::StatementInvalid,
                       /duplicate key value violates unique constraint/)
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

  describe '#decorate' do
    it 'returns a IdentityDecorator' do
      identity = build(:service_provider_identity)

      expect(identity.decorate).to be_a(IdentityDecorator)
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
end
