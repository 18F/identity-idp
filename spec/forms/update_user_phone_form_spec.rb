require 'rails_helper'

describe UpdateUserPhoneForm do
  let(:user) { build_stubbed(:user, :signed_up) }
  subject { UpdateUserPhoneForm.new(user) }

  it do
    is_expected.
      to validate_presence_of(:phone).
      with_message(t('errors.messages.improbable_phone'))
  end

  describe 'phone validation' do
    it 'uses the phony_rails gem with country option set to US' do
      phone_validator = subject._validators.values.flatten.
                        detect { |v| v.class == PhonyPlausibleValidator }

      expect(phone_validator.options).
        to eq(country_code: 'US', presence: true, message: :improbable_phone)
    end
  end

  def format_phone(phone)
    phone.phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )
  end

  describe 'phone uniqueness' do
    context 'when phone is already taken' do
      it 'is valid' do
        second_user = build_stubbed(:user, :signed_up, phone: '+1 (202) 555-1213')
        allow(User).to receive(:exists?).with(email: 'new@gmail.com').and_return(false)
        allow(User).to receive(:exists?).with(phone: second_user.phone).and_return(true)

        subject.phone = second_user.phone

        expect(subject.valid?).to be true
      end
    end

    context 'when phone is not already taken' do
      it 'is valid' do
        subject.phone = '+1 (703) 555-1212'

        expect(subject.valid?).to be true
      end
    end

    context 'when phone is same as current user' do
      it 'is valid' do
        subject.phone = user.phone

        expect(subject.valid?).to be true
      end
    end

    context 'when phone is nil' do
      it 'does not add already taken errors' do
        subject.phone = nil

        expect(subject.valid?).to be false
        expect(subject.errors[:phone].uniq).
          to eq [t('errors.messages.improbable_phone')]
      end
    end
  end

  describe 'OTP delivery preference' do
    context 'when updating phone number' do
      let(:params) { { phone: '+1 (705) 705-7005' } }

      context 'when changing SMS enabled' do
        before do
          params[:sms_otp_delivery] = '1'
          subject.submit(params)
        end

        it 'requires confirmation' do
          expect(subject.require_phone_confirmation?).to be_truthy
        end
      end

      context 'when not changing SMS enabled' do
        before do
          params[:sms_otp_delivery] = '0'
          subject.submit(params)
        end

        it 'requires confirmation' do
          expect(subject.require_phone_confirmation?).to be_truthy
        end
      end
    end

    context 'when SMS disabled and enabling SMS' do
      let(:user) { build_stubbed(:user, :signed_up, sms_otp_delivery: false) }
      let(:params) do
        { phone: user.phone,
          sms_otp_delivery: '1' }
      end

      subject { UpdateUserPhoneForm.new(user) }

      it 'requires confirmation' do
        subject.submit(params)
        expect(subject.require_phone_confirmation?).to be_truthy
      end
    end

    context 'when SMS enabled and disabling SMS' do
      let(:user) { build_stubbed(:user, :signed_up) }
      let(:params) do
        { phone: user.phone,
          sms_otp_delivery: '0' }
      end

      subject { UpdateUserPhoneForm.new(user) }

      it 'requires confirmation' do
        subject.submit(params)
        expect(subject.require_phone_confirmation?).to be_truthy
      end
    end

    context 'when not changing SMS preference' do
      let(:user_sms) { build_stubbed(:user, :signed_up, sms_otp_delivery: true) }
      let(:user_no_sms) { build_stubbed(:user, :signed_up, sms_otp_delivery: false) }

      context 'when SMS enabled' do
        let(:params) do
          { phone: user_sms.phone,
            sms_otp_delivery: '1' }
        end

        subject { UpdateUserPhoneForm.new(user_sms) }

        it 'does not require confirmation' do
          subject.submit(params)
          expect(subject.require_phone_confirmation?).to be false
        end
      end

      context 'when SMS disabled' do
        let(:params) do
          { phone: user_no_sms.phone,
            sms_otp_delivery: '0' }
        end

        subject { UpdateUserPhoneForm.new(user_no_sms) }

        it 'does not require confirmation' do
          subject.submit(params)
          expect(subject.require_phone_confirmation?).to be false
        end
      end
    end
  end
end
