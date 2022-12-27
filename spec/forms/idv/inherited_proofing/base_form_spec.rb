require 'rails_helper'

RSpec.describe Idv::InheritedProofing::BaseForm do
  subject { form_object }

  let(:form_class) do
    Class.new(Idv::InheritedProofing::BaseForm) do
      class << self
        def required_fields; [] end

        def optional_fields; [] end
      end

      def user_pii; {} end
    end
  end

  let(:form_object) do
    form_class.new(payload_hash: payload_hash)
  end

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

  describe '#initialize' do
    subject { form_class }

    context 'when .user_pii is not overridden' do
      subject do
        Class.new(Idv::InheritedProofing::BaseForm) do
          class << self
            def required_fields; [] end

            def optional_fields; [] end
          end
        end
      end

      it 'raises an error' do
        expected_error = 'Override this method and return a user PII Hash'
        expect { subject.new(payload_hash: payload_hash).user_pii }.to raise_error(expected_error)
      end
    end
  end

  describe 'class methods' do
    describe '.model_name' do
      it 'returns the right model name' do
        expect(described_class.model_name).to eq 'IdvInheritedProofingBaseForm'
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
    subject do
      Class.new(Idv::InheritedProofing::BaseForm) do
        class << self
          def required_fields; %i[required] end

          def optional_fields; %i[optional] end
        end

        def user_pii; {} end
      end.new(payload_hash: payload_hash)
    end

    let(:payload_hash) do
      {
        required: 'Required',
        optional: 'Optional',
      }
    end

    context 'with valid payload data' do
      it 'returns true' do
        expect(subject.validate).to eq true
      end
    end

    context 'with invalid payload data' do
      context 'when the payload has unrecognized fields' do
        let(:payload_hash) do
          {
            xrequired: 'xRequired',
            xoptional: 'xOptional',
          }
        end

        let(:expected_error_messages) do
          [
            # Required field presence
            'Required field is missing',
            'Optional field is missing',
          ]
        end

        it 'returns true' do
          expect(subject.validate).to eq true
        end
      end

      context 'when the payload has missing required field data' do
        let(:payload_hash) do
          {
            required: nil,
            optional: '',
          }
        end

        it 'returns true' do
          expect(subject.validate).to eq true
        end

        it 'returns no errors because no data validations take place by default' do
          subject.validate
          expect(subject.errors.full_messages).to eq []
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

      it 'calls #valid?' do
        expect(subject).to receive(:valid?).once
      end
    end
  end
end
