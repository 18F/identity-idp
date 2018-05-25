require 'rails_helper'

describe Identity do
  let(:user) { create(:user, :signed_up) }
  let(:identity) do
    Identity.create(
      user_id: user.id,
      service_provider: 'externalapp'
    )
  end
  subject { identity }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:service_provider) }

  describe '.deactivate' do
    let(:active_identity) { create(:identity, :active) }

    it 'sets last_authenticated_at to nil' do
      active_identity.deactivate
      expect(identity.last_authenticated_at).to be_nil
    end
  end

  describe 'uuid validations' do
    it 'uses a DB constraint to enforce presence' do
      identity = create(:identity)
      identity.uuid = nil

      expect { identity.save }.
        to raise_error(ActiveRecord::StatementInvalid,
                       /null value in column "uuid" violates not-null constraint/)
    end

    it 'uses a DB index to enforce uniqueness' do
      identity1 = create(:identity)
      identity1.save
      identity2 = create(:identity)
      identity2.uuid = identity1.uuid

      expect { identity2.save }.
        to raise_error(ActiveRecord::StatementInvalid,
                       /duplicate key value violates unique constraint/)
    end
  end

  describe '#generate_uuid' do
    it 'calls generate_uuid before creation' do
      identity = build(:identity, uuid: 'foo')

      expect(identity).to receive(:generate_uuid)

      identity.save
    end

    context 'when already has a uuid' do
      it 'returns the current uuid' do
        identity = create(:identity)
        old_uuid = identity.uuid

        expect(identity.generate_uuid).to eq old_uuid
      end
    end

    context 'when does not already have a uuid' do
      it 'generates it via SecureRandom.uuid' do
        identity = build(:identity)

        expect(identity.generate_uuid).
          to match(/[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}/)
      end
    end
  end

  describe '#decorate' do
    it 'returns a IdentityDecorator' do
      identity = build(:identity)

      expect(identity.decorate).to be_a(IdentityDecorator)
    end
  end

  let(:service_provider) do
    create(:service_provider)
  end

  let(:identity_with_sp) do
    Identity.create(
      user_id: user.id,
      service_provider: service_provider.issuer
    )
  end

  describe '#display_name' do
    it 'returns service provider friendly name first' do
      expect(identity_with_sp.display_name).to eq(service_provider.friendly_name)
    end

    it 'returns service_provider agency if friendly_name is missing' do
      service_provider.friendly_name = nil
      service_provider.save
      expect(identity_with_sp.display_name).to eq(service_provider.agency)
    end

    it 'returns service_provider issuer if friendly_name and agency are missing' do
      service_provider.friendly_name = nil
      service_provider.agency = nil
      service_provider.save
      expect(identity_with_sp.display_name).to eq(service_provider.issuer)
    end
  end

  describe '#agency_name' do
    it 'returns service provider agency first' do
      expect(identity_with_sp.agency_name).to eq(service_provider.agency)
    end

    it 'returns service_provider friendly_name if agency is missing' do
      service_provider.agency = nil
      service_provider.save
      expect(identity_with_sp.agency_name).to eq(service_provider.friendly_name)
    end

    it 'returns service_provider issuer if friendly_name and agency are missing' do
      service_provider.friendly_name = nil
      service_provider.agency = nil
      service_provider.save
      expect(identity_with_sp.agency_name).to eq(service_provider.issuer)
    end
  end

  describe '#piv_cac_available?' do
    context 'when agency configured to support piv/cac' do
      before(:each) do
        allow(Figaro.env).to receive(:piv_cac_agencies).and_return(
          [service_provider.agency].to_json
        )
        PivCacService.send(:reset_piv_cac_avaialable_agencies)
      end

      it 'returns truthy' do
        expect(identity_with_sp.piv_cac_available?).to be_truthy
      end
    end

    context 'when agency is not configured to support piv/cac' do
      before(:each) do
        allow(Figaro.env).to receive(:piv_cac_agencies).and_return(
          [service_provider.agency + 'X'].to_json
        )
        PivCacService.send(:reset_piv_cac_avaialable_agencies)
      end

      it 'returns falsey' do
        expect(identity_with_sp.piv_cac_available?).to be_falsey
      end
    end
  end

  describe 'uniqueness validation for service provider per user' do
    it 'raises an error when uniqueness constraint is broken' do
      Identity.create(user_id: user.id, service_provider: 'externalapp')
      expect { Identity.create(user_id: user.id, service_provider: 'externalapp') }.
        to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'does not raise an error for a different service provider' do
      Identity.create(user_id: user.id, service_provider: 'externalapp')
      expect { Identity.create(user_id: user.id, service_provider: 'externalapp2') }.
        to_not raise_error
    end
  end
end
