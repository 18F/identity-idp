require 'rails_helper'

RSpec.describe Idv::PhoneForm do
  let(:user) { build_stubbed(:user, :fully_registered) }
  let(:phone) { '703-555-5000' }
  let(:params) { { phone: phone } }
  let(:previous_params) { nil }
  let(:allowed_countries) { nil }
  let(:optional_params) { {} }

  subject do
    Idv::PhoneForm.new(
      user: user,
      previous_params: previous_params,
      allowed_countries: allowed_countries,
      **optional_params,
    )
  end

  it_behaves_like 'a phone form'

  describe '#submit' do
    let(:result) { subject.submit(params) }

    context 'when the form is valid' do
      context 'when a phone number is provided' do
        let(:phone) { '703-555-1212' }

        it 'returns a successful form response' do
          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end
    end

    context 'when the form is invalid' do
      it 'returns an unsuccessful form response' do
        result = subject.submit(phone: 'Im not a phone number 🙃')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).to include(:phone)
        expect(result.errors[:phone]).to include(t('errors.messages.improbable_phone'))
      end
    end

    context 'with user phone number' do
      let(:phone) { '7035551234' }
      let(:user) { build_stubbed(:user, :fully_registered, with: { phone: phone }) }

      it 'uses the formatted phone number as the initial phone value' do
        expect(subject.phone).to eq('+1 703-555-1234')
      end

      context 'with supported international user phone number' do
        let(:phone) { '+63 905 123 4567' }

        it 'uses the user phone number as the initial phone value' do
          expect(subject.phone).to eq(phone)
        end
        it 'infers the country code from the user phone number' do
          expect(subject.international_code).to eq('PH')
        end
      end

      context 'in Puerto Rico' do
        let(:phone) { '+17872345678' }
        let(:optional_params) { { delivery_methods: [:sms] } }

        it 'uses the user phone number as the initial phone value' do
          expect(subject.phone).to eq('+1 787-234-5678')
        end
        it 'infers the country code from the user phone number' do
          expect(subject.international_code).to eq('PR')
        end
      end

      # We use Romania for this test because it is a region where
      # the default config will not allow sending SMS to unregistered
      # numbers
      context 'in country that only supports SMS for registered phones' do
        let(:phone) { '+400258567233' }
        let(:optional_params) { { delivery_methods: [:sms] } }
        let(:allowed_countries) { ['RO'] }

        it 'allows using registered phone number even if it is formatted differently' do
          differently_formatted_phone = Phonelib.parse(phone).e164
          expect(subject.submit(phone: differently_formatted_phone).success?).to eq true
        end

        it 'does not allow using unregistered phone number' do
          unregistered_phone = '+400258567234'
          result = subject.submit(phone: unregistered_phone)
          expect(result.success?).to eq false
          expect(result.to_h).to include(error_details: { phone: { sms_unsupported: true } })
        end
      end

      context 'with international user phone number in unsupported country' do
        let(:phone) { '+213 0551 23 45 67' }

        it 'does not use the user phone number as the initial phone value' do
          expect(subject.phone).to eq(nil)
        end
        it 'does not infer the country code from the user phone number' do
          expect(subject.international_code).to eq(nil)
        end
      end

      context 'with international user phone number in disallowed country' do
        let(:phone) { '+61 0412 345 678' }
        let(:allowed_countries) { ['US'] }

        it 'does not use the user phone number as the initial phone value' do
          expect(subject.phone).to eq(nil)
        end
        it 'does not infer the country code from the user phone number' do
          expect(subject.international_code).to eq(nil)
        end
      end
    end

    context 'with a number submitted on the hybrid handoff step' do
      context 'with a phone number on the user record' do
        let(:user_phone) { '2025555000' }
        let(:hybrid_handoff_phone_number) { '2025551234' }
        let(:user) { build_stubbed(:user, :fully_registered, with: { phone: user_phone }) }
        let(:optional_params) { { hybrid_handoff_phone_number: hybrid_handoff_phone_number } }

        it 'uses the user phone as the initial value' do
          expect(subject.phone).to eq(PhoneFormatter.format(user_phone))
        end
      end

      context 'without a phone number on the user record' do
        let(:hybrid_handoff_phone_number) { '2025551234' }
        let(:user) { build_stubbed(:user) }
        let(:optional_params) { { hybrid_handoff_phone_number: hybrid_handoff_phone_number } }

        it 'uses the hybrid handoff phone as the initial value' do
          expect(subject.phone).to eq(PhoneFormatter.format(hybrid_handoff_phone_number))
        end
      end
    end

    context 'with previously submitted value' do
      let(:user) { build_stubbed(:user, :fully_registered, with: { phone: '7035551234' }) }
      let(:previous_params) { { phone: '2255555000' } }

      it 'uses the previously submitted value as the initial phone value' do
        expect(subject.phone).to eq('+1 225-555-5000')
        expect(subject.international_code).to eq('US')
      end

      context 'including country' do
        let(:previous_params) { { phone: '2255555000', international_code: 'IE' } }
        it 'uses the previously submitted phone + country as the initial values' do
          expect(subject.phone).to eq('+353 225 555 5000')
          expect(subject.international_code).to eq('IE')
        end
      end

      context 'including other keys' do
        let(:previous_params) do
          {
            'phone' => '+17872345678',
            'otp_delivery_preference' => 'sms',
          }
        end
        it 'uses the previously submitted phone + and infers country' do
          expect(subject.phone).to eq('+1 787-234-5678')
          expect(subject.international_code).to eq('PR')
        end
      end
    end

    context 'with specific allowed countries' do
      let(:allowed_countries) { ['PR', 'US'] }

      it 'validates to only allow numbers from permitted countries' do
        invalid_phones = ['+81 54 354 3643', '+12423270143']
        invalid_phones.each do |phone|
          result = subject.submit(phone: phone)

          expect(result.success?).to eq(false)
          expect(result.errors[:phone]).to include(t('errors.messages.improbable_phone'))
        end
        valid_phones = ['+1 (939) 555-0123']
        valid_phones.each do |phone|
          result = subject.submit(phone: phone)

          expect(result.success?).to eq(true)
        end
      end

      context 'with US as the sole allowed country' do
        let(:allowed_countries) { ['US'] }

        it 'validates to only allow numbers from permitted countries' do
          invalid_phones = ['+81 54 354 3643', '+12423270143']
          invalid_phones.each do |phone|
            result = subject.submit(phone: phone)

            expect(result.success?).to eq(false)
            expect(result.errors[:phone]).to include(t('errors.messages.improbable_phone'))
          end
          valid_phones = ['7035551234']
          valid_phones.each do |phone|
            result = subject.submit(phone: phone)

            expect(result.success?).to eq(true)
          end
        end
      end
    end

    context 'with specific delivery methods' do
      let(:optional_params) { { delivery_methods: [:voice] } }

      it 'validates to only allow numbers from permitted countries' do
        invalid_phones = {
          Philippines: '+63 0905 123 4567',
          Canada: '3065551234',
        }
        invalid_phones.each do |location, phone|
          result = subject.submit(phone: phone)
          message = t(
            'two_factor_authentication.otp_delivery_preference.voice_unsupported',
            location: location,
          )

          expect(result.success?).to eq(false)
          expect(result.errors[:phone]).to include(message)
        end
        valid_phones = ['5135551234']
        valid_phones.each do |phone|
          result = subject.submit(phone: phone)

          expect(result.success?).to eq(true)
        end
      end
    end

    context 'with unsupported delivery method' do
      let(:unsupported_delivery_methods) { [] }
      let(:result) { subject.submit(params) }

      before do
        allow(subject).to receive(:unsupported_delivery_methods).
          and_return(unsupported_delivery_methods)
      end

      context 'with one unsupported delivery method' do
        let(:unsupported_delivery_methods) { [:sms] }

        it 'is valid' do
          expect(result.success?).to eq(true)
          expect(result.errors).to eq({})
        end
      end

      context 'with all delivery methods unsupported' do
        let(:unsupported_delivery_methods) { [:sms, :voice] }

        it 'is invalid' do
          expect(result.success?).to eq(false)
          expect(result.errors).to eq(
            phone: [
              t(
                'two_factor_authentication.otp_delivery_preference.sms_unsupported',
                location: 'United States',
              ),
              t(
                'two_factor_authentication.otp_delivery_preference.voice_unsupported',
                location: 'United States',
              ),
            ],
          )
        end
      end
    end
  end
end
