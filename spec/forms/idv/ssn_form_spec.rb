require 'rails_helper'

RSpec.describe Idv::SsnForm do
  let(:user) { create(:user) }
  let(:subject) { Idv::SsnForm.new(user) }
  let(:ssn) { '111111111' }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(ssn: ssn)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra).to eq(ssn_is_unique: true)
      end

      context 'when the SSN is a duplicate' do
        before { create(:profile, pii: { ssn: ssn }) }

        it 'logs that there is a duplicate SSN' do
          result = subject.submit(ssn: ssn)
          expect(result.extra).to eq(ssn_is_unique: false)
        end
      end
    end

    context 'when the form is invalid' do
      it 'returns an unsuccessful form response' do
        result = subject.submit(ssn: 'abc')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).to include(:ssn)
      end
    end

    context 'when the form has invalid attributes' do
      it 'raises an error' do
        expect { subject.submit(ssn: ssn, foo: 1) }.
          to raise_error(ArgumentError, 'foo is an invalid ssn attribute')
      end
    end
  end

  describe 'presence validations' do
    it 'is invalid when required attribute is not present' do
      subject.submit(ssn: nil)

      expect(subject).to_not be_valid
    end
  end
end
