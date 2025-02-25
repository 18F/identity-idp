require 'rails_helper'

RSpec.describe UspsInPersonProofing::TransliterableValidator do
  let(:errors) { ActiveModel::Errors.new(nil) }
  let(:valid_field) { nil }
  let(:invalid_field) { nil }
  let(:extra_field) { nil }
  let(:other_invalid_field) { nil }
  let(:model) do
    double(
      'SomeModel',
      errors:,
      valid_field:,
      invalid_field:,
      extra_field:,
      other_invalid_field:,
    )
  end

  let(:message) { 'Test message' }
  let(:fields) { [:valid_field] }
  let(:reject_chars) { /[^A-Za-z]/ }
  let(:options) do
    {
      fields:,
      reject_chars:,
      message:,
    }
  end

  subject(:validator) { described_class.new(options) }

  describe '#validate' do
    let(:valid_field) { 'abc' }
    let(:extra_field) { 'hello world' }

    before do
      allow(validator.transliterator).to receive(:transliterate) do |param|
        UspsInPersonProofing::Transliterator::TransliterationResult.new(
          changed?: true,
          original: param,
          transliterated: "transliterated#{param}",
          unsupported_chars: [],
        )
      end
    end

    context 'no invalid fields' do
      context 'with missing field' do
        let(:fields) { [:missing_field, :valid_field] }

        it 'does not check the configured field that is missing' do
          expect do
            validator.validate(model)
          end.not_to raise_error
        end
      end

      context 'with non-stringable field' do
        let(:valid_field) { non_str_double }
        let(:non_str_double) { double }

        it 'does not attempt to transliterate the field' do
          allow(non_str_double).to receive(:respond_to?).with(:to_s).and_return(false)

          validator.validate(model)
          expect(validator.transliterator).not_to have_received(:transliterate)
        end
      end

      it 'does not check the non-configured field that is present' do
        validator.validate(model)
        expect(model).not_to have_received(:extra_field)
      end

      it 'checks the configured field that is present' do
        validator.validate(model)
        expect(model).to have_received(:valid_field)
      end

      it 'does not set validation message' do
        validator.validate(model)
        expect(errors).to be_empty
      end
    end

    context 'one invalid field' do
      let(:fields) { [:valid_field, :invalid_field] }

      context 'failing regex check' do
        let(:invalid_field) { '123' }

        it 'sets a validation message' do
          validator.validate(model)

          expect(model.errors).to include(:invalid_field)
        end
      end

      context 'failing transliteration' do
        let(:invalid_field) { 'def' }
        let(:analytics) { FakeAnalytics.new }

        before do
          allow(validator).to receive(:analytics).and_return(analytics)
          allow(validator.transliterator).to receive(:transliterate).with('def')
            .and_return(
              UspsInPersonProofing::Transliterator::TransliterationResult.new(
                changed?: true,
                original: 'def',
                transliterated: 'efg',
                unsupported_chars: ['*', '3', 'C'],
              ),
            )
        end

        it 'sets a validation message' do
          validator.validate(model)

          error = model.errors.group_by_attribute[:invalid_field].first

          expect(error.type).to eq(:nontransliterable_field)
          expect(error.options[:message]).to eq(message)
        end

        it 'logs nontransliterable characters' do
          validator.validate(model)

          expect(analytics).to have_logged_event(
            'IdV: in person proofing characters submitted could not be transliterated',
            nontransliterable_characters: ['*', '3', 'C'],
          )
        end
      end

      context 'with callable error message' do
        let(:generated_message) { 'my_generated_message' }
        let(:chars_passed) { [] }
        let(:message) do
          proc do |invalid_chars|
            chars_passed.push(*invalid_chars)
            generated_message
          end
        end

        context 'combined transliteration and regex issues' do
          let(:unsupported_chars_returned) { ['*', '3', 'C'] }
          let(:transliterated_value_returned) { '1234' }
          let(:invalid_field) { 'def' }
          before do
            allow(validator.transliterator).to receive(:transliterate).with('def')
              .and_return(
                UspsInPersonProofing::Transliterator::TransliterationResult.new(
                  changed?: true,
                  original: 'def',
                  transliterated: transliterated_value_returned,
                  unsupported_chars: unsupported_chars_returned,
                ),
              )
          end

          context 'with remaining question mark in transliterated string' do
            let(:transliterated_value_returned) do
              "#{UspsInPersonProofing::Transliterator::REPLACEMENT * 4}1234"
            end

            it 'passes unique sorted chars to message generator' do
              # The replacement character needs special treatment in this test,
              # hence this precondition check.
              expect(
                transliterated_value_returned.count(
                  UspsInPersonProofing::Transliterator::REPLACEMENT,
                ),
              ).to be > unsupported_chars_returned.size

              validator.validate(model)

              expect(chars_passed).to eq(
                ['*', '1', '2', '3', '4',
                 UspsInPersonProofing::Transliterator::REPLACEMENT, 'C'],
              )
            end
          end

          context 'without remaining question mark in transliterated string' do
            it 'passes unique sorted chars to message generator' do
              # The replacement character needs special treatment in this test,
              # hence this precondition check.
              expect(
                transliterated_value_returned.count(
                  UspsInPersonProofing::Transliterator::REPLACEMENT,
                ),
              ).to be <= unsupported_chars_returned.size

              validator.validate(model)

              expect(chars_passed).to eq(['*', '1', '2', '3', '4', 'C'])
            end
          end

          it 'sets the error from the message returned by the message generator' do
            validator.validate(model)

            error = model.errors.group_by_attribute[:invalid_field].first
            expect(error.type).to eq(:nontransliterable_field)
            expect(error.options[:message]).to eq(generated_message)
          end
        end
      end
    end

    context 'multiple invalid fields' do
      let(:fields) { [:other_invalid_field, :valid_field, :invalid_field] }
      let(:invalid_field) { '123' }
      let(:other_invalid_field) { "\#@$%" }
      let(:analytics) { FakeAnalytics.new }

      before do
        allow(validator).to receive(:analytics).and_return(analytics)
      end

      it 'sets multiple validation messages' do
        validator.validate(model)

        expect(errors).to include(:invalid_field)
        expect(errors).to include(:other_invalid_field)
      end

      it 'logs nontransliterable characters' do
        validator.validate(model)

        expect(analytics).to have_logged_event(
          'IdV: in person proofing characters submitted could not be transliterated',
          nontransliterable_characters: ['#', '$', '%', '1', '2', '3', '@'],
        )
      end
    end
  end
end
