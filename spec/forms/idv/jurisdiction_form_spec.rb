require 'rails_helper'

describe Idv::JurisdictionForm do
  let(:supported_jurisdiction) { 'WA' }
  let(:unsupported_jurisdiction) { 'CA' }

  let(:subject) { Idv::JurisdictionForm.new }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit({ state: supported_jurisdiction })

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when the form is invalid' do
      it 'returns an unsuccessful form response' do
        result = subject.submit({ state: unsupported_jurisdiction })

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).to include(:state)
      end
    end
  end

  describe 'presence validations' do
    it 'is invalid when required attribute is not present' do
      subject.submit({ state: nil })

      expect(subject).to_not be_valid
    end
  end

  describe 'jurisdiction validity' do
    it 'populates error for unsupported jurisdiction ' do
      subject.submit({ state: unsupported_jurisdiction })
      expect(subject.valid?).to eq false
      expect(subject.errors[:state]).to eq [I18n.t('idv.errors.unsupported_jurisdiction')]
    end
  end
end
