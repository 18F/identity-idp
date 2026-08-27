require 'rails_helper'

RSpec.describe Idv::HowToVerifyForm do
  let(:subject) { Idv::HowToVerifyForm.new }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(selection: Idv::HowToVerifyForm::REMOTE)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end

      it 'accepts the clear1 selection' do
        result = subject.submit(selection: Idv::HowToVerifyForm::CLEAR1)

        expect(result.success?).to eq(true)
      end
    end

    context 'when the selection is not a known option' do
      it 'returns an unsuccessful form response' do
        result = subject.submit(selection: 'carrier_pigeon')

        expect(result.success?).to eq(false)
        expect(result.errors[:selection]).to be_present
      end
    end
  end

  describe 'presence validations' do
    it 'is invalid when required attribute is not present' do
      subject.submit(selection: nil)

      expect(subject).to_not be_valid
    end
  end
end
