require 'rails_helper'

RSpec.describe ServiceProviderIdentity do
  let(:user) { create(:user, :fully_registered) }
  let(:verified_attributes) { [] }
  let(:identity) do
    ServiceProviderIdentity.create(
      user_id: user.id,
      service_provider: 'externalapp',
      verified_attributes:,
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

      expect { identity.save }
        .to raise_error(
          ActiveRecord::NotNullViolation,
          /null value in column "uuid".*violates not-null constraint/,
        )
    end

    it 'uses a DB index to enforce uniqueness' do
      identity1 = create(:service_provider_identity)
      identity1.save
      identity2 = create(:service_provider_identity)
      identity2.uuid = identity1.uuid

      expect { identity2.save }
        .to raise_error(
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

        expect(identity.generate_uuid)
          .to match(/[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}/)
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
  end

  describe 'uniqueness validation for service provider per user' do
    it 'raises an error when uniqueness constraint is broken' do
      ServiceProviderIdentity.create(user_id: user.id, service_provider: 'externalapp')
      expect { ServiceProviderIdentity.create(user_id: user.id, service_provider: 'externalapp') }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'does not raise an error for a different service provider' do
      ServiceProviderIdentity.create(user_id: user.id, service_provider: 'externalapp')
      expect { ServiceProviderIdentity.create(user_id: user.id, service_provider: 'externalapp2') }
        .to_not raise_error
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

  describe '#verified_single_email_attribute?' do
    subject(:verified_single_email_attribute?) { identity.verified_single_email_attribute? }

    context 'with attributes nil' do
      let(:verified_attributes) { nil }

      it { is_expected.to be false }
    end

    context 'with no attributes verified' do
      let(:verified_attributes) { [] }

      it { is_expected.to be false }
    end

    context 'with a non-email attribute verified' do
      let(:verified_attributes) { ['openid'] }

      it { is_expected.to be false }
    end

    context 'with all_emails attribute verified' do
      let(:verified_attributes) { ['all_emails'] }

      it { is_expected.to be false }
    end

    context 'with email attribute verified' do
      let(:verified_attributes) { ['email'] }

      it { is_expected.to be true }

      context 'with all_emails attribute verified' do
        let(:verified_attributes) { ['email', 'all_emails'] }

        it { is_expected.to be false }
      end
    end
  end

  describe '#email_address_for_sharing' do
    let!(:last_login_email_address) do
      create(
        :email_address,
        email: 'last_login@email.com',
        user: user,
        last_sign_in_at: 1.minute.ago,
      )
    end

    let!(:shared_email_address) do
      create(
        :email_address,
        email: 'shared@email.com',
        user: user,
        last_sign_in_at: 1.hour.ago,
      )
    end

    let(:service_provider) { create(:service_provider) }

    let(:identity) do
      create(
        :service_provider_identity,
        user: user,
        session_uuid: SecureRandom.uuid,
        service_provider: service_provider.issuer,
      )
    end

    context 'when an email address is set' do
      before do
        identity.email_address = shared_email_address
      end

      it 'returns the shared email' do
        expect(identity.email_address_for_sharing).to eq(shared_email_address)
      end
    end

    context 'when an email address for sharing has not been set' do
      before do
        identity.email_address = nil
      end
      it 'returns the last login email' do
        expect(identity.email_address_for_sharing).to eq(last_login_email_address)
      end
    end
  end

  describe '#clear_email_address_id_if_not_supported' do
    let(:verified_attributes) { %w[email] }
    let!(:shared_email_address) do
      create(
        :email_address,
        email: 'shared@email.com',
        user: user,
        last_sign_in_at: 1.hour.ago,
      )
    end
    let(:identity) do
      create(
        :service_provider_identity,
        user: user,
        session_uuid: SecureRandom.uuid,
        service_provider: service_provider.issuer,
        verified_attributes: verified_attributes,
        email_address_id: shared_email_address.id,
      )
    end

    context 'when user has only email as the verified attribute attribute' do
      let(:new_shared_email_address) do
        create(
          :email_address,
          email: 'shared2@email.com',
          user: user,
          last_sign_in_at: 1.hour.ago,
        )
      end

      it 'should save the new email properly on update' do
        identity.update!(email_address_id: new_shared_email_address.id)
        expect(identity.email_address).to eq(new_shared_email_address)
      end
    end

    context 'when user has all_emails as the verified attribute' do
      let(:verified_attributes) { %w[all_emails] }
      let(:new_shared_email_address) do
        create(
          :email_address,
          email: 'shared2@email.com',
          user: user,
          last_sign_in_at: 1.hour.ago,
        )
      end

      it 'should make the email address to nil' do
        identity.update!(email_address_id: new_shared_email_address.id)
        expect(identity.email_address).to eq(nil)
      end
    end
  end
end
