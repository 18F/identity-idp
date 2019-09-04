require 'rails_helper'

describe EditPhoneForm do
  include Shoulda::Matchers::ActiveModel

  let(:user) { build(:user, :signed_up) }
  let(:params) do
    {
      otp_delivery_preference: 'sms',
    }
  end
  subject { EditPhoneForm.new(user, MfaContext.new(user).phone_configurations.first) }

  describe '#submit' do
    context 'when otp_delivery_preference is not voice or sms' do
      let(:params) do
        {
          otp_delivery_preference: 'foo',
        }
      end

      it 'is invalid' do
        result = subject.submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:otp_delivery_preference].first).
          to eq 'is not included in the list'
      end
    end

    context 'when phone is valid' do
      it 'includes otp preference in the form response extra' do
        result = subject.submit(params)

        expect(result.extra).to eq(
                                  otp_delivery_preference: params[:otp_delivery_preference],
                                  )
      end
    end

    context 'when otp_delivery_preference is empty' do
      let(:params) do
        {
          otp_delivery_preference: '',
        }
      end

      it 'is invalid' do
        result = subject.submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:otp_delivery_preference].first).
          to eq 'is not included in the list'
      end
    end

    it 'revokes the users rememder device sessions' do
      subject.submit(params)

      expect(user.reload.remember_device_revoked_at).to be_within(1.second).of(Time.zone.now)
    end
  end
end
