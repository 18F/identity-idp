require 'rails_helper'

describe UserPhoneForm do
  let(:user) { build(:user, :signed_up) }
  let(:params) do
    {
      phone: '555-555-5000',
      international_code: 'US',
      otp_delivery_preference: 'sms',
    }
  end
  subject { UserPhoneForm.new(user) }

  it_behaves_like 'a phone form'

  it 'loads initial values from the user object' do
    user = build_stubbed(
      :user,
      phone: '+1 (555) 500-5000',
      otp_delivery_preference: 'voice'
    )
    subject = UserPhoneForm.new(user)

    expect(subject.phone).to eq(user.phone)
    expect(subject.international_code).to eq('US')
    expect(subject.otp_delivery_preference).to eq(user.otp_delivery_preference)
  end

  it 'infers the international code from the user phone number' do
    user = build_stubbed(:user, phone: '+81 744 21 1234')
    subject = UserPhoneForm.new(user)

    expect(subject.international_code).to eq('JP')
  end

  describe '#submit' do
    context 'when phone is valid' do
      it 'is valid' do
        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end

      it 'include otp preference in the form response extra' do
        result = subject.submit(params)

        expect(result.extra).to eq(
          otp_delivery_preference: params[:otp_delivery_preference]
        )
      end

      it 'does not update the user phone attribute' do
        user = create(:user)
        subject = UserPhoneForm.new(user)
        params[:phone] = '+1 504 444 1643'

        subject.submit(params)

        user.reload
        expect(user.phone).to_not eq('+1 504 444 1643')
      end

      it 'preserves the format of the submitted phone number if phone is invalid' do
        params[:phone] = '555-555-5000'
        params[:international_code] = 'MA'

        result = subject.submit(params)

        expect(result.success?).to eq(false)
        expect(subject.phone).to eq('555-555-5000')
      end
    end

    context 'when otp_delivery_preference is voice and phone number does not support voice' do
      let(:guam_phone) { '671-555-5000' }
      let(:params) do
        {
          phone: guam_phone,
          international_code: 'US',
          otp_delivery_preference: 'voice',
        }
      end

      it 'is invalid' do
        result = subject.submit(params)

        expect(result.success?).to eq(false)
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

  describe '#phone_changed?' do
    it 'returns true if the user phone has changed' do
      params[:phone] = '+1 504 444 1643'
      subject.submit(params)

      expect(subject.phone_changed?).to eq(true)
    end

    it 'returns false if the user phone has not changed' do
      params[:phone] = user.phone
      subject.submit(params)

      expect(subject.phone_changed?).to eq(false)
    end
  end
end
