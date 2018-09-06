require 'rails_helper'

describe UserPhoneForm do
  include Shoulda::Matchers::ActiveModel

  let(:user) { build(:user, :signed_up) }
  let(:params) do
    {
      phone: '703-555-5000',
      international_code: 'US',
      otp_delivery_preference: 'sms',
    }
  end
  subject { UserPhoneForm.new(user, user.mfa.phone_configurations.first) }

  it_behaves_like 'a phone form'

  it 'loads initial values from the user object' do
    user = build_stubbed(
      :user, :with_phone,
      with: { phone: '+1 (703) 500-5000' },
      otp_delivery_preference: 'voice'
    )
    subject = UserPhoneForm.new(user, user.mfa.phone_configurations.first)

    expect(subject.phone).to eq(user.mfa.phone_configurations.first.phone)
    expect(subject.international_code).to eq('US')
    expect(subject.otp_delivery_preference).to eq(user.otp_delivery_preference)
  end

  it 'infers the international code from the user phone number' do
    user = build_stubbed(:user, :with_phone, with: { phone: '+81 744 21 1234' })
    subject = UserPhoneForm.new(user, user.mfa.phone_configurations.first)

    expect(subject.international_code).to eq('JP')
  end

  describe 'phone validation' do
    it do
      should validate_inclusion_of(:international_code).
        in_array(PhoneNumberCapabilities::INTERNATIONAL_CODES.keys)
    end

    it 'validates that the number matches the requested international code' do
      params[:phone] = '123 123 1234'
      params[:international_code] = 'MA'
      result = subject.submit(params)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to include(:phone)
    end
  end

  describe '#submit' do
    context 'when phone is valid' do
      it 'is valid' do
        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end

      it 'includes otp preference in the form response extra' do
        result = subject.submit(params)

        expect(result.extra).to eq(
          otp_delivery_preference: params[:otp_delivery_preference]
        )
      end

      it 'does not update the user phone attribute' do
        user = create(:user)
        subject = UserPhoneForm.new(user, user.mfa.phone_configurations.first)
        params[:phone] = '+1 504 444 1643'

        subject.submit(params)

        user.reload
        expect(user.mfa.phone_configurations).to be_empty
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
      let(:unsupported_phone) { '242-327-0143' }
      let(:params) do
        {
          phone: unsupported_phone,
          international_code: 'US',
          otp_delivery_preference: 'voice',
        }
      end

      it 'is invalid' do
        result = subject.submit(params)

        expect(result.success?).to eq(false)
      end
    end

    context 'when otp_delivery_preference is not voice or sms' do
      let(:params) do
        {
          phone: '703-555-1212',
          international_code: 'US',
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

    context "when the submitted otp_delivery_preference is different from the user's" do
      it "updates the user's otp_delivery_preference" do
        user_updater = instance_double(UpdateUser)
        allow(UpdateUser).
          to receive(:new).
          with(
            user: user,
            attributes: { otp_delivery_preference: 'voice' }
          ).
          and_return(user_updater)
        expect(user_updater).to receive(:call)

        params = {
          phone: '703-555-5000',
          international_code: 'US',
          otp_delivery_preference: 'voice',
        }

        subject.submit(params)
      end
    end

    context "when the submitted otp_delivery_preference is the same as the user's" do
      it "does not update the user's otp_delivery_preference" do
        expect(UpdateUser).to_not receive(:new)

        subject.submit(params)
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
      params[:phone] = user.mfa.phone_configurations.first.phone
      subject.submit(params)

      expect(subject.phone_changed?).to eq(false)
    end

    context 'when a user has no phone' do
      it 'returns true' do
        user.mfa.phone_configurations.clear

        params[:phone] = '+1 504 444 1643'
        subject.submit(params)

        expect(subject.phone_changed?).to eq(true)
      end
    end
  end
end
