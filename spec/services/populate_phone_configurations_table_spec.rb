require 'rails_helper'

describe PopulatePhoneConfigurationsTable do
  let(:subject) { described_class.new }

  describe '#call' do
    context 'a user with no phone' do
      let!(:user) { create(:user) }

      it 'migrates nothing' do
        subject.call
        expect(user.reload.phone_configuration).to be_nil
      end
    end

    context 'a user with a phone' do
      let!(:user) { create(:user, :with_phone) }

      context 'and no phone_configuration entry' do
        before(:each) do
          user.phone_configuration.delete
          user.reload
        end

        it 'migrates without decrypting and re-encrypting' do
          expect(EncryptedAttribute).to_not receive(:new)
          subject.call
        end

        it 'migrates the phone' do
          subject.call
          configuration = user.reload.phone_configuration
          expect(configuration.phone).to eq user.phone
          expect(configuration.confirmed_at).to eq user.phone_confirmed_at
          expect(configuration.delivery_preference).to eq user.otp_delivery_preference
        end
      end

      context 'and an existing phone_configuration entry' do
        it 'adds no new rows' do
          expect(PhoneConfiguration.where(user_id: user.id).count).to eq 1
          subject.call
          expect(PhoneConfiguration.where(user_id: user.id).count).to eq 1
        end
      end
    end
  end
end
