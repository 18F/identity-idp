require 'rails_helper'

RSpec.describe NewPhoneForm do
  include Shoulda::Matchers::ActiveModel

  let(:user) { build(:user, :fully_registered) }
  let(:phone) { '703-555-5000' }
  let(:international_code) { 'US' }
  let(:params) { { phone:, international_code:, otp_delivery_preference: 'sms' } }

  subject(:form) { NewPhoneForm.new(user:) }

  it_behaves_like 'a phone form'

  describe 'phone validation' do
    context 'with valid international code' do
      it 'is valid' do
        PhoneNumberCapabilities::INTERNATIONAL_CODES.keys.each do |code|
          result = subject.submit(params.clone.merge(international_code: code))

          expect(result.to_h[:error_details]).not_to match(
            hash_including(international_code: include(:inclusion)),
          )
        end
      end
    end

    context 'with invalid international code' do
      it 'is invalid' do
        result = subject.submit(params.clone.merge(international_code: 'INVALID'))

        expect(result.to_h[:error_details]).to match(
          hash_including(international_code: include(:inclusion)),
        )
      end
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
        subject = NewPhoneForm.new(user:)
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
    end

    context 'when the user has already added the number' do
      it 'is invalid' do
        phone = PhoneFormatter.format('+1 (954) 555-0100', country_code: 'US')
        params[:phone] = phone
        create(:phone_configuration, user: user, phone: phone)

        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:phone]).to eq([I18n.t('errors.messages.phone_duplicate')])
      end

      it 'is invalid if database phone is not formatted' do
        unformatted_phone = '+1 954 5550100'
        params[:phone] = '+1 9545550100'
        create(:phone_configuration, user: user, phone: unformatted_phone)

        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:phone]).to eq([I18n.t('errors.messages.phone_duplicate')])
      end

      it 'is invalid if existing phone is international' do
        unformatted_phone = '+610491570006'
        params[:phone] = '+61 0491 570 006'
        params[:international_code] = 'CA'
        create(:phone_configuration, user: user, phone: unformatted_phone)

        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:phone]).to eq([I18n.t('errors.messages.phone_duplicate')])
      end
    end

    context 'vendor reports phone number is invalid' do
      let(:phone) { '+44 113 496 0000' }

      subject(:result) do
        form.submit(params.merge(phone: phone))
      end

      before do
        allow(IdentityConfig.store).to receive(:phone_service_check).and_return(true)

        expect(Telephony).to receive(:phone_info).with(phone).
          and_raise(Aws::Pinpoint::Errors::BadRequestException.new(nil, nil))
      end

      it 'is invalid and does not raise' do
        expect { result }.to_not raise_error

        expect(result.success?).to eq(false)
        expect(result.errors[:phone]).to be_present
      end

      it 'includes redacted information for the error log' do
        expect(result.to_h).to include(
          redacted_phone: '+## ### ### ####',
          country_code: 'GB',
        )
      end
    end

    context 'voip numbers' do
      let(:telephony_gem_voip_number) { '+12255552000' }
      let(:voip_block) { false }
      let(:phone_service_check) { true }

      before do
        allow(IdentityConfig.store).to receive(:voip_block).and_return(voip_block)
        allow(IdentityConfig.store).to receive(:phone_service_check).and_return(phone_service_check)
      end

      subject(:result) do
        form.submit(params.merge(phone: telephony_gem_voip_number))
      end

      context 'when voip numbers are blocked' do
        let(:voip_block) { true }

        it 'is invalid' do
          expect(result.success?).to eq(false)
          expect(result.errors[:phone]).to eq([I18n.t('errors.messages.voip_phone')])
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

        context 'when AWS rate limits info type checks' do
          before do
            expect(Telephony).to receive(:phone_info).
              and_raise(Aws::Pinpoint::Errors::TooManyRequestsException.new(nil, 'error message'))
          end

          it 'logs a warning and fails open' do
            expect(result.extra[:warn]).to include('AWS pinpoint phone info rate limit')

            expect(result.success?).to eq(true)
            expect(result.errors).to be_blank
          end
        end

        context 'when voip checks are disabled' do
          let(:phone_service_check) { false }

          it 'does not check the phone type' do
            expect(Telephony).to_not receive(:phone_info)

            result
          end

          it 'allows voip numbers since it cannot check the type' do
            expect(result.success?).to eq(true)
            expect(result.errors).to be_blank
          end
        end
      end

      context 'when voip numbers are allowed' do
        let(:voip_block) { false }

        it 'does a voip check but does not enforce it' do
          expect(Telephony).to receive(:phone_info).and_call_original

          expect(result.success?).to eq(true)
          expect(result.to_h).to include(phone_type: :voip)
        end
      end

      context 'when voip checks are disabled' do
        let(:phone_service_check) { false }

        it 'does not check the phone type' do
          expect(Telephony).to_not receive(:phone_info)

          result
        end
      end
    end

    context 'blocklisted carrier numbers' do
      before do
        allow(IdentityConfig.store).to receive(:phone_carrier_registration_blocklist).and_return(
          ['Blocked Phone Carrier'],
        )
      end

      context 'when phone number carrier is in blocklist' do
        it 'is invalid' do
          expect(Telephony).to receive(:phone_info).and_return(
            Telephony::PhoneNumberInfo.new(
              type: :mobile,
              carrier: 'Blocked Phone Carrier',
              error: nil,
            ),
          )

          result = subject.submit(params)
          expect(result.success?).to eq(false)
          expect(result.errors[:phone]).to eq([I18n.t('errors.messages.phone_carrier')])
        end
      end
    end

    context 'premium rate phone numbers like 1-900' do
      let(:premium_rate_phone_number) { '+1 900 867 5309' }

      subject(:result) do
        form.submit(params.merge(phone: premium_rate_phone_number))
      end

      it 'is invalid' do
        expect(result.success?).to eq(false)
        expect(result.errors[:phone]).to be_present
      end

      it 'logs the type' do
        expect(result.extra).to include(
          types: [:premium_rate],
        )
      end
    end

    context 'with recaptcha mock validator' do
      let(:recaptcha_mock_score) { nil }
      let(:score_threshold) { 0.6 }
      let(:recaptcha_token) { 'token' }
      let(:phone) { '0491 570 006' }
      let(:international_code) { 'AU' }
      let(:params) { super().merge(recaptcha_token:, recaptcha_mock_score:) }

      subject(:result) { form.submit(params) }

      before do
        allow(IdentityConfig.store).to receive(:phone_recaptcha_mock_validator).and_return(true)
        allow(IdentityConfig.store).to receive(:phone_recaptcha_score_threshold).
          and_return(score_threshold)
      end

      context 'with invalid captcha score' do
        let(:recaptcha_mock_score) { score_threshold - 0.1 }

        it 'is invalid' do
          expect(result.success?).to eq(false)
          expect(result.errors[:recaptcha_token]).to be_present
        end
      end

      context 'with valid captcha score' do
        let(:recaptcha_mock_score) { score_threshold + 0.1 }

        it 'is valid' do
          expect(result.success?).to eq(true)
          expect(result.errors).to be_blank
        end
      end
    end

    context 'with recaptcha enabled' do
      let(:valid) { nil }
      let(:validator) { PhoneRecaptchaValidator.new(recaptcha_version: 3, parsed_phone: nil) }
      let(:recaptcha_token) { 'token' }
      let(:phone) { '3065550100' }
      let(:international_code) { 'CA' }
      let(:params) { super().merge(recaptcha_token:) }

      subject(:result) { form.submit(params) }

      before do
        allow(FeatureManagement).to receive(:phone_recaptcha_enabled?).and_return(true)
        allow(validator).to receive(:valid?).with(recaptcha_token).and_return(valid)
        allow(form).to receive(:recaptcha_validator).and_return(validator)
      end

      context 'with valid recaptcha result' do
        let(:valid) { true }

        it 'is valid' do
          expect(result.success?).to eq(true)
          expect(result.errors).to be_blank
        end

        it 'does not override default recaptcha version' do
          result

          expect(form.recaptcha_version).to eq(3)
        end

        context 'with recaptcha_version parameter' do
          let(:params) { super().merge(recaptcha_version:) }

          context 'with v2 parameter' do
            let(:recaptcha_version) { '2' }

            it 'overrides default recaptcha version' do
              result

              expect(form.recaptcha_version).to eq(2)
            end
          end

          context 'with invalid parameter' do
            let(:recaptcha_version) { '4' }

            it 'does not override default recaptcha version' do
              result

              expect(form.recaptcha_version).to eq(3)
            end
          end
        end

        context 'with recaptcha enterprise' do
          let(:validator) do
            PhoneRecaptchaValidator.new(
              recaptcha_version: 3,
              validator_class: RecaptchaEnterpriseValidator,
              parsed_phone: nil,
            )
          end

          before do
            allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(true)
          end

          it 'is valid' do
            expect(result.success?).to eq(true)
            expect(result.errors).to be_blank
          end
        end
      end

      context 'with invalid recaptcha result' do
        let(:valid) { false }

        it 'is invalid' do
          expect(result.success?).to eq(false)
          expect(result.errors[:recaptcha_token]).to be_present
        end
      end
    end
  end

  describe '#delivery_preference_sms?' do
    it 'is true' do
      expect(form.delivery_preference_sms?).to eq(true)
    end

    context 'sms outage' do
      before do
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
      end

      it 'is false' do
        expect(form.delivery_preference_sms?).to eq(false)
      end
    end
  end

  describe '#delivery_preference_voice?' do
    it 'is false' do
      expect(form.delivery_preference_voice?).to eq(false)
    end

    context 'sms outage' do
      before do
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
      end

      it 'is true' do
        expect(form.delivery_preference_voice?).to eq(true)
      end
    end

    context 'with setup_voice_preference present' do
      subject(:form) { NewPhoneForm.new(user:, setup_voice_preference: true) }

      it 'is true' do
        expect(form.delivery_preference_voice?).to eq(true)
      end
    end
  end
end
