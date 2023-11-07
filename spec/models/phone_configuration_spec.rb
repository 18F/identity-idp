require 'rails_helper'

RSpec.describe PhoneConfiguration do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:encrypted_phone) }
  end

  let(:phone) { '+1 703 555 1212' }

  let(:phone_configuration) { create(:phone_configuration, phone:) }

  describe 'creation' do
    it 'stores an encrypted form of the phone number' do
      expect(phone_configuration.encrypted_phone).to_not be_blank
    end
  end

  describe 'encrypted attributes' do
    it 'decrypts phone' do
      expect(phone_configuration.phone).to eq phone
    end

    context 'with unnormalized phone' do
      let(:phone) { '  555 555 5555     ' }
      let(:normalized_phone) { '555 555 5555' }

      it 'normalizes phone' do
        expect(phone_configuration.phone).to eq normalized_phone
      end
    end
  end

  describe '#masked_phone' do
    let(:phone_configuration) { build(:phone_configuration, phone:) }
    let(:phone) { '+1 703 555 1212' }

    subject(:masked_phone) { phone_configuration.masked_phone }

    it 'masks the phone number, leaving the last 4 digits' do
      expect(masked_phone).to eq('(***) ***-1212')
    end

    context 'with a blank phone number' do
      let(:phone) { '   ' }

      it 'is the empty string' do
        expect(masked_phone).to eq('')
      end
    end

    context 'with an international number' do
      let(:phone) { '+212 636-023853' }

      it 'keeps the groupings and leaves the last 4 digits' do
        expect(masked_phone).to eq('****-**3853')
      end
    end
  end
end
