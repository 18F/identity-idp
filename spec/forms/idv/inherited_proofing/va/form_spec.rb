require 'rails_helper'

RSpec.shared_examples 'the hash is blank?' do
  it 'raises an error' do
    expect { subject }.to raise_error 'payload_hash is blank?'
  end
end

RSpec.describe Idv::InheritedProofing::Va::Form do
  subject(:form) { described_class.new payload_hash: payload_hash }

  let(:payload_hash) do
    {
      first_name: 'Henry',
      last_name: 'Ford',
      phone: '12222222222',
      birth_date: '2000-01-01',
      ssn: '111223333',
      address: {
        street: '1234 Model Street',
        street2: 'Suite A',
        city: 'Detroit',
        state: 'MI',
        country: 'United States',
        zip: '12345',
      },
    }
  end

  describe 'class methods' do
    describe '.model_name' do
      it 'returns the right model name' do
        expect(described_class.model_name).to eq 'IdvInheritedProofingVaForm'
      end
    end

    describe '.field_names' do
      let(:expected_field_names) do
        [
          :address_city,
          :address_country,
          :address_state,
          :address_street,
          :address_street2,
          :address_zip,
          :birth_date,
          :first_name,
          :last_name,
          :phone,
          :ssn,
        ].sort
      end

      it 'returns the right model name' do
        expect(described_class.field_names).to match_array expected_field_names
      end
    end
  end

  describe '#initialize' do
    context 'when passing an invalid payload hash' do
      context 'when not a Hash' do
        let(:payload_hash) { :x }

        it 'raises an error' do
          expect { subject }.to raise_error 'payload_hash is not a Hash'
        end
      end

      context 'when nil?' do
        let(:payload_hash) { nil }

        it_behaves_like 'the hash is blank?'
      end

      context 'when empty?' do
        let(:payload_hash) { {} }

        it_behaves_like 'the hash is blank?'
      end
    end

    context 'when passing a valid payload hash' do
      it 'raises no errors' do
        expect { subject }.to_not raise_error
      end
    end
  end

  describe '#validate' do
    context 'with a valid payload' do
      it 'returns true'
    end

    context 'with an invalid payload' do
      context 'when the payload has missing fields' do
        it 'returns false'
      end

      context 'when the payload has invalid field data' do
        it 'returns false'
      end
    end
  end

  describe '#submit' do
    it 'returns a FormResponse object' do
      expect(subject.submit).to be_kind_of FormResponse
    end

    describe 'before returning' do
      after do
        subject.submit
      end

      it 'calls #validate' do
        expect(subject).to receive(:validate).once
      end
    end

    context 'with an invalid payload' do
      context 'when the payload has missing fields' do
        it 'returns a FormResponse indicating errors'
      end

      context 'when the payload has invalid field data' do
        it 'returns a FormResponse indicating errors'
      end
    end
  end
end
