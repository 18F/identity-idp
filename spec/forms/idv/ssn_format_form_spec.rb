require 'rails_helper'

RSpec.describe Idv::SsnFormatForm do
  let(:ssn) { '111-11-1111' }
  let(:incoming_ssn) { nil }

  subject { Idv::SsnFormatForm.new(incoming_ssn) }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(ssn: '111111111')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when the form is valid with incoming_ssn provided' do
      let(:incoming_ssn) { ssn }

      it 'returns a successful form response' do
        result = subject.submit(ssn: '111111111')

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
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
        expect { subject.submit(ssn: '111111111', foo: 1) }.
          to raise_error(ArgumentError, 'foo is an invalid ssn attribute')
      end
    end
  end

  describe '#updating_ssn?' do
    context 'when no value is provided' do
      subject { Idv::SsnFormatForm.new(nil) }

      it { expect(subject.updating_ssn?).to eq(false) }
    end

    context 'when there is an SSN provided from idv_session.ssn' do
      let(:incoming_ssn) { ssn }

      it { expect(subject.updating_ssn?).to eq(true) }
    end
  end

  describe 'presence validations' do
    it 'is invalid when required attribute is not present' do
      subject.submit(ssn: nil)

      expect(subject).to_not be_valid
    end
  end
end
