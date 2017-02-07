require 'rails_helper'

describe Idv::PhoneForm do
  let(:user) { build_stubbed(:user, :signed_up) }
  subject { Idv::PhoneForm.new({}, user) }

  it_behaves_like 'a phone form'

  describe '#submit' do
    it 'adds phone key to idv_params when valid' do
      subject.submit(phone: '703-555-1212')

      expected_params = {
        phone: '+1 (703) 555-1212',
      }

      expect(subject.idv_params).to eq expected_params
    end

    it 'adds phone_confirmed_at key to idv_params when submitted phone equals user phone' do
      subject.submit(phone: '+1 (202) 555-1212')

      expected_params = {
        phone: user.phone,
        phone_confirmed_at: user.phone_confirmed_at,
      }

      expect(subject.idv_params).to eq expected_params
    end
  end
end
