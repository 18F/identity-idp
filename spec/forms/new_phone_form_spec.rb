require 'rails_helper'

describe NewPhoneForm do
  include Shoulda::Matchers::ActiveModel

  let(:user) { build(:user, :signed_up) }
  let(:params) do
    {
      phone: '703-555-5000',
      international_code: 'US',
      otp_delivery_preference: 'sms',
    }
  end
  subject(:form) { NewPhoneForm.new(user) }

  it_behaves_like 'a phone form'

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

        expect(result.extra).to include(
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

    it 'does not raise inclusion errors for Norwegian phone numbers' do
      # ref: https://github.com/18F/identity-private/issues/2392
      params[:phone] = '21 11 11 11'
      params[:international_code] = 'NO'
      result = subject.submit(params)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
    end

    context 'voip numbers' do
      let(:telephony_gem_voip_number) { '+12255552000' }

      subject(:result) do
        form.submit(params.merge(phone: telephony_gem_voip_number))
      end

      context 'when voip numbers are blocked' do
        before do
          expect(FeatureManagement).to receive(:voip_block?).and_return(true)
        end

        it 'is invalid' do
          expect(result.success?).to eq(false)
          expect(result.errors[:phone]).to eq([I18n.t('errors.messages.voip_check_error')])
        end

        it 'logs the type and carrier' do
          expect(result.extra).to include(
            phone_type: :voip,
            carrier: 'Test VOIP Carrier',
          )
        end

        context 'when the number is on the allowlist' do
          before do
            expect(FeatureManagement).to receive(:voip_allowed_phones).
              and_return([telephony_gem_voip_number])
          end

          it 'is valid' do
            expect(result.success?).to eq(true)
            expect(result.errors).to be_blank
          end
        end
      end

      context 'when voip numbers are allowed' do
        before do
          expect(FeatureManagement).to receive(:voip_block?).and_return(false)
        end

        it 'does a voip check but does not enforce it' do
          expect(Telephony).to receive(:phone_info).and_call_original

          expect(result.success?).to eq(true)
          expect(result.to_h).to include(phone_type: :voip)
        end
      end
    end
  end
end
