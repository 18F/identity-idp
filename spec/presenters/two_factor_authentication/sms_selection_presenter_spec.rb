require 'rails_helper'

describe TwoFactorAuthentication::SmsSelectionPresenter do
  let(:subject) { described_class.new(phone) }

  describe '#type' do
    context 'when a user has only one phone configuration' do
      let(:user) { create(:user, :with_phone) }
      let(:phone) { MfaContext.new(user).phone_configurations.first }

      it 'returns sms' do
        expect(subject.type).to eq 'sms'
      end
    end

    context 'when a user has more than one phone configuration' do
      let(:user) { create(:user, :with_phone) }
      let(:phone) do
        record = create(:phone_configuration, user: user)
        user.reload
        record
      end

      it 'returns sms:id' do
        expect(subject.type).to eq "sms_#{phone.id}"
      end
    end
  end
end
