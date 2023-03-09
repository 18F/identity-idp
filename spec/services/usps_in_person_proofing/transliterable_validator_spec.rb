require 'rails_helper'

RSpec.describe UspsInPersonProofing::TransliterableValidator do
  let(:errors) { instance_double(ActiveModel::Errors) }
  let(:model) { double }
  let(:transliterator) { instance_double(UspsInPersonProofing::Transliterator) }
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
  subject(:validator) do
    subject = described_class.new(options)
    allow(subject).to receive(:transliterator).and_return(transliterator)
    subject
  end

  describe '#validate' do
    context 'transliteration enabled' do
      before(:each) do
        allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
          and_return(true)
        allow(model).to receive(:errors).and_return(errors)
        allow(model).to receive(:valid_field).and_return('abc')
        allow(model).to receive(:extra_field).and_return('hello world')
        allow(transliterator).to receive(:transliterate) do |param|
          UspsInPersonProofing::Transliterator::TransliterationResult.new(
            changed?: true,
            original: param,
            transliterated: "transliterated#{param}",
            unsupported_chars: [],
          )
        end
        allow(errors).to receive(:add)
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
          it 'does not attempt to transliterate the field' do
            non_str_double = double
            allow(non_str_double).to receive(:respond_to?).with(:to_s).and_return(false)
            allow(model).to receive(:valid_field).and_return(non_str_double)
            validator.validate(model)
            expect(validator).not_to have_received(:transliterator)
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
          expect(errors).not_to have_received(:add)
        end
      end

      context 'one invalid field' do
        let(:fields) { [:valid_field, :invalid_field] }

        context 'failing regex check' do
          before(:each) do
            allow(model).to receive(:invalid_field).and_return('123')
          end

          it 'sets a validation message' do
            validator.validate(model)
            expect(errors).to have_received(:add).with(
              :invalid_field,
              :nontransliterable_field,
              message:,
            )
          end
        end

        context 'failing transliteration' do
          before(:each) do
            allow(model).to receive(:invalid_field).and_return('def')
            allow(transliterator).to receive(:transliterate).with('def').
              and_return(
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
            expect(errors).to have_received(:add).with(
              :invalid_field,
              :nontransliterable_field,
              message: message,
            )
          end
        end

        context 'with error message callable' do
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
            before(:each) do
              allow(model).to receive(:invalid_field).and_return('def')
              allow(transliterator).to receive(:transliterate).with('def').
                and_return(
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
              expect(errors).to have_received(:add).with(
                :invalid_field,
                :nontransliterable_field,
                message: generated_message,
              )
            end
          end
        end
      end

      context 'multiple invalid fields' do
        let(:fields) { [:other_invalid_field, :valid_field, :invalid_field] }
        before(:each) do
          allow(model).to receive(:invalid_field).and_return('123')
          allow(model).to receive(:other_invalid_field).and_return("\#@$%")
        end

        it 'checks both invalid fields' do
          validator.validate(model)
          expect(model).to have_received(:invalid_field)
          expect(model).to have_received(:other_invalid_field)
        end

        it 'sets multiple validation messages' do
          validator.validate(model)
          expect(errors).to have_received(:add).with(
            :invalid_field,
            :nontransliterable_field,
            message:,
          )
          expect(errors).to have_received(:add).with(
            :other_invalid_field,
            :nontransliterable_field,
            message:,
          )
        end
      end
    end

    context 'transliteration disabled' do
      before(:each) do
        allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
          and_return(false)
        allow(model).to receive(:errors).and_return(errors)
        allow(model).to receive(:valid_field).and_return('abc')
      end

      it 'does not validate fields' do
        validator.validate(model)
        expect(model).not_to have_received(:errors)
        expect(model).not_to have_received(:valid_field)
        expect(validator).not_to have_received(:transliterator)
      end
    end
  end
end
