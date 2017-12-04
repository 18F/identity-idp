require 'rails_helper'

describe Idv::PhoneForm do
  let(:user) { build_stubbed(:user, :signed_up) }
  let(:params) { { phone: '555-555-5000' } }

  subject { Idv::PhoneForm.new({}, user) }

  it_behaves_like 'a phone form'

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(phone: '703-555-1212')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end

      it 'adds phone key to idv_params' do
        subject.submit(phone: '703-555-1212')

        expected_params = {
          phone: '7035551212',
          phone_confirmed_at: nil,
        }

        expect(subject.idv_params).to eq expected_params
      end
    end

    context 'when the form is invalid' do
      it 'returns an unsuccessful form response' do
        result = subject.submit(phone: 'Im not a phone number 🙃')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).to include(:phone)
      end
    end

    it 'adds phone_confirmed_at key to idv_params when submitted phone equals user phone' do
      subject.submit(phone: '+1 (202) 555-1212')

      expected_params = {
        phone: '2025551212',
        phone_confirmed_at: user.phone_confirmed_at,
      }

      expect(subject.idv_params).to eq expected_params
    end

    it 'uses the user phone number as the initial phone value' do
      user = build_stubbed(:user, :signed_up, phone: '555-555-1234')
      subject = Idv::PhoneForm.new({}, user)

      expect(subject.phone).to eq('+1 (555) 555-1234')
    end

    it 'does not use an international number as the initial phone value' do
      user = build_stubbed(:user, :signed_up, phone: '+81 54 354 3643')
      subject = Idv::PhoneForm.new({}, user)

      expect(subject.phone).to eq(nil)
    end

    it 'does not allow numbers with a non-US country code' do
      result = subject.submit(phone: '+81 54 354 3643')

      expect(result.success?).to eq(false)
      expect(result.errors[:phone]).to include(t('errors.messages.must_have_us_country_code'))
    end
  end
end
