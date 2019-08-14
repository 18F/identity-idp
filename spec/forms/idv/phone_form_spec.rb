require 'rails_helper'

describe Idv::PhoneForm do
  let(:user) { build_stubbed(:user, :signed_up) }
  let(:params) { { phone: '703-555-5000' } }
  let(:previous_params) { nil }

  subject { Idv::PhoneForm.new(user: user, previous_params: previous_params) }

  it_behaves_like 'a phone form'

  describe '#submit' do
    let(:result) { subject.submit(params) }

    context 'when the form is valid' do
      context 'when a phone number is provided' do
        let(:params) { { phone: '703-555-1212' } }

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
      end
    end

    it 'uses the user phone number as the initial phone value' do
      user = build_stubbed(:user, :signed_up, with: { phone: '7035551234' })
      subject = Idv::PhoneForm.new(previous_params: {}, user: user)

      expect(subject.phone).to eq('+1 703-555-1234')
    end

    it 'does not use an international number as the initial phone value' do
      user = build_stubbed(:user, :signed_up, with: { phone: '+81 54 354 3643' })
      subject = Idv::PhoneForm.new(previous_params: {}, user: user)

      expect(subject.phone).to eq(nil)
    end

    it 'uses the previously submitted value as the initial phone value' do
      user = build_stubbed(:user, :signed_up, with: { phone: '7035551234' })
      subject = Idv::PhoneForm.new(previous_params: { phone: '2255555000' }, user: user)

      expect(subject.phone).to eq('+1 225-555-5000')
    end

    it 'does not allow non-US numbers' do
      invalid_phones = ['+81 54 354 3643', '+12423270143']
      invalid_phones.each do |phone|
        result = subject.submit(phone: phone)

        expect(result.success?).to eq(false)
        expect(result.errors[:phone]).to include(t('errors.messages.must_have_us_country_code'))
      end
    end
  end
end
