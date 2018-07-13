require 'rails_helper'

RSpec.describe TwoFactorAuthentication::VoiceConfiguration do
  let(:subject) { described_class.new(user: user) }

  context 'with a phone configured' do
    let(:user) { build(:user, :with_phone) }

    context 'and not sms only' do
      it 'is available' do
        allow(PhoneNumberCapabilities).to receive(:new).with(user.phone).and_return(
          OpenStruct.new(sms_only?: false)
        )

        expect(subject.available?).to eq true
      end
    end

    context 'and sms only' do
      it 'is available' do
        allow(PhoneNumberCapabilities).to receive(:new).with(user.phone).and_return(
          OpenStruct.new(sms_only?: true)
        )

        expect(subject.available?).to eq false
      end
    end
  end

  context 'with no phone configured' do
    let(:user) { build(:user) }

    it 'is available' do
      expect(subject.available?).to eq true
    end
  end
end
