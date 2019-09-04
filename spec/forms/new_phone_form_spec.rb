require 'rails_helper'

describe NewPhoneForm do
  include Shoulda::Matchers::ActiveModel

  let(:user) { build(:user, :signed_up) }
  let(:params) do
    {
      otp_delivery_preference: 'sms',
    }
  end
  subject { NewPhoneForm.new(user) }

  describe '#submit' do
    context 'when phone is valid' do
      it 'includes otp preference in the form response extra' do
        result = subject.submit(params)

        expect(result.extra).to eq(
          otp_delivery_preference: params[:otp_delivery_preference],
        )
      end

      it 'does not update the user phone attribute' do
        user = create(:user)
        subject = NewPhoneForm.new(user)
        params[:phone] = '+1 504 444 1643'

        subject.submit(params)

        user.reload
        expect(MfaContext.new(user).phone_configurations).to be_empty
      end
    end

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

    context 'when otp_delivery_preference is empty' do
      let(:params) do
        {
          phone: '703-555-1212',
          international_code: 'US',
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

    context 'when otp_delivery_preference param is not present' do
      let(:params) do
        {
          phone: '703-555-1212',
          international_code: 'US',
        }
      end

      it 'is valid' do
        result = subject.submit(params)

        expect(result.success?).to eq(true)
      end
    end

    it 'does not raise inclusion errors for Norwegian phone numbers' do
      # ref: https://github.com/18F/identity-private/issues/2392
      params[:phone] = '21 11 11 11'
      params[:international_code] = 'NO'
      result = subject.submit(params)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
    end
  end
end
