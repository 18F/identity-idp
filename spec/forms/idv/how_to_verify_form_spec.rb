require 'rails_helper'

RSpec.describe Idv::HowToVerifyForm do
  let(:subject) { Idv::HowToVerifyForm.new }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(selection: 'remote')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
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
