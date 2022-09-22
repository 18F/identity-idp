require 'rails_helper'

describe Idv::PhoneForm do
  let(:user) { build_stubbed(:user, :signed_up) }
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
      let(:user) { build_stubbed(:user, :signed_up, with: { phone: phone }) }

      it 'uses the formatted phone number as the initial phone value' do
        expect(subject.phone).to eq('+1 703-555-1234')
      end

      context 'with supported international user phone number' do
        let(:phone) { '+63 905 123 4567' }

        it 'uses the user phone number as the initial phone value' do
          expect(subject.phone).to eq(phone)
        end
      end

      context 'with international user phone number in unsupported country' do
        let(:phone) { '+213 0551 23 45 67' }

        it 'does not use the user phone number as the initial phone value' do
          expect(subject.phone).to eq(nil)
        end
      end

      context 'with international user phone number in disallowed country' do
        let(:phone) { '+61 0412 345 678' }
        let(:allowed_countries) { ['US'] }

        it 'does not use the user phone number as the initial phone value' do
          expect(subject.phone).to eq(nil)
        end
      end
    end

    context 'with previously submitted value' do
      let(:user) { build_stubbed(:user, :signed_up, with: { phone: '7035551234' }) }
      let(:previous_params) { { phone: '2255555000' } }

      it 'uses the previously submitted value as the initial phone value' do
        expect(subject.phone).to eq('+1 225-555-5000')
      end
    end

    context 'with specific allowed countries' do
      let(:allowed_countries) { ['MP', 'US'] }

      it 'validates to only allow numbers from permitted countries' do
        invalid_phones = ['+81 54 354 3643', '+12423270143']
        invalid_phones.each do |phone|
          result = subject.submit(phone: phone)

          expect(result.success?).to eq(false)
          expect(result.errors[:phone]).to include(t('errors.messages.improbable_phone'))
        end
        valid_phones = ['+1 (670) 555-0123']
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
            expect(result.errors[:phone]).to include(t('errors.messages.must_have_us_country_code'))
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
  end
end
