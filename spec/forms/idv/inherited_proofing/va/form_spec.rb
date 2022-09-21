require 'rails_helper'

RSpec.shared_examples 'the hash is blank?' do
  it 'raises an error' do
    expect { subject }.to raise_error 'payload_hash is blank?'
  end
end

RSpec.describe Idv::InheritedProofing::Va::Form do
  subject(:form) { described_class.new payload_hash: payload_hash }

  let(:required_fields) { %i[first_name last_name birth_date ssn address_street address_zip] }
  let(:optional_fields) { %i[phone address_street2 address_city address_state address_country] }

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

    describe '.fields' do
      it 'returns all the fields' do
        expect(described_class.fields).to match_array required_fields + optional_fields
      end
    end

    describe '.required_fields' do
      it 'returns the required fields' do
        expect(described_class.required_fields).to match_array required_fields
      end
    end

    describe '.optional_fields' do
      it 'returns the optional fields' do
        expect(described_class.optional_fields).to match_array optional_fields
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
    context 'with valid payload data' do
      it 'returns true' do
        expect(subject.validate).to eq true
      end
    end

    context 'with invalid payload data' do
      context 'when the payload has missing fields' do
        let(:payload_hash) do
          {
            xfirst_name: 'Henry',
            xlast_name: 'Ford',
            xphone: '12222222222',
            xbirth_date: '2000-01-01',
            xssn: '111223333',
            xaddress: {
              xstreet: '1234 Model Street',
              xstreet2: 'Suite A',
              xcity: 'Detroit',
              xstate: 'MI',
              xcountry: 'United States',
              xzip: '12345',
            },
          }
        end

        let(:expected_error_messages) do
          [
            # Required field presence
            'First name field is missing',
            'Last name field is missing',
            'Phone field is missing',
            'Birth date field is missing',
            'Ssn field is missing',
            'Address street field is missing',
            'Address street2 field is missing',
            'Address city field is missing',
            'Address state field is missing',
            'Address country field is missing',
            'Address zip field is missing',
          ]
        end

        it 'returns false' do
          expect(subject.validate).to eq false
        end

        it 'adds the correct error messages for missing fields' do
          subject.validate
          expect(
            expected_error_messages.all? do |error_message|
              subject.errors.full_messages.include? error_message
            end,
          ).to eq true
        end
      end

      context 'when the payload has missing required field data' do
        let(:payload_hash) do
          {
            first_name: nil,
            last_name: '',
            phone: nil,
            birth_date: '',
            ssn: nil,
            address: {
              street: '',
              street2: nil,
              city: '',
              state: nil,
              country: '',
              zip: nil,
            },
          }
        end

        let(:expected_error_messages) do
          [
            # Required field data presence
            'First name Please fill in this field.',
            'Last name Please fill in this field.',
            'Birth date Please fill in this field.',
            'Ssn Please fill in this field.',
            'Address street Please fill in this field.',
            'Address zip Please fill in this field.',
          ]
        end

        it 'returns false' do
          expect(subject.validate).to eq false
        end

        it 'adds the correct error messages for required fields that are missing data' do
          subject.validate
          expect(subject.errors.full_messages).to match_array expected_error_messages
        end
      end

      context 'when the payload has missing optional field data' do
        let(:payload_hash) do
          {
            first_name: 'x',
            last_name: 'x',
            phone: nil,
            birth_date: '01/01/2022',
            ssn: '123456789',
            address: {
              street: 'x',
              street2: nil,
              city: '',
              state: nil,
              country: '',
              zip: '12345',
            },
          }
        end

        it 'returns true' do
          expect(subject.validate).to eq true
        end
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

  describe '#user_pii' do
    let(:expected_user_pii) do
      {
        first_name: subject.first_name,
        last_name: subject.last_name,
        dob: subject.birth_date,
        ssn: subject.ssn,
        phone: subject.phone,
        address1: subject.address_street,
        city: subject.address_city,
        state: subject.address_state,
        zipcode: subject.address_zip,
      }
    end
    it 'returns the correct user pii' do
      expect(subject.user_pii).to eq expected_user_pii
    end
  end
end
