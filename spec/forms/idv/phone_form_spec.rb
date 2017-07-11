require 'rails_helper'

describe Idv::PhoneForm do
  let(:user) { build_stubbed(:user, :signed_up) }
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
  end
end
