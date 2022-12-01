require 'rails_helper'

describe DataRequests::LookupUserByUuid do
  describe '#call' do
    context 'when a user exists with the UUID' do
      it 'returns the user' do
        user = create(:user)
        uuid = user.uuid

        expect(described_class.new(uuid).call).to eq(user)
      end
    end

    context 'when an identity exists with the UUID' do
      context 'when it has consented for the SP' do
        it 'returns the user for the identity' do
          identity = create(:service_provider_identity)
          uuid = identity.uuid

          expect(described_class.new(uuid).call).to eq(identity.user)
        end
      end

      context 'when it has not consented for the SP' do
        it 'does not return the identity for the user' do
          identity = create(:service_provider_identity, :non_consented)
          uuid = identity.uuid

          expect(described_class.new(uuid).call).to be_nil
        end
      end
    end

    context 'when nothing exists for the UUID' do
      it 'returns nil' do
        expect(described_class.new('123abc').call).to be_nil
      end
    end
  end
end
