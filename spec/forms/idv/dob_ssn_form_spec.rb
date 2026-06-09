require 'rails_helper'

RSpec.describe Idv::DobSsnForm do
  let(:ssn) { '111111111' }
  let(:dob) { '1990-01-01' }
  let(:pii) do
    {
      ssn: ssn,
      dob: dob,
    }
  end

  subject { Idv::DobSsnForm.new(pii) }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(ssn: '111-11-1111', dob: { year: '1990', month: '01', day: '01' })
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when the form is invalid' do
      it 'returns an unsuccessful form response' do
        result = subject.submit(ssn: 'abc', dob: '123')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).to include(:ssn, :dob)
      end
    end
  end

  describe 'presence validations' do
    it 'is invalid when required attribute is not present' do
      subject.submit(ssn: nil, dob: nil)

      expect(subject).to_not be_valid
    end
  end
end
