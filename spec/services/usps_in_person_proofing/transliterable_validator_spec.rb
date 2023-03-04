require 'rails_helper'

RSpec.describe UspsInPersonProofing::TransliterableValidator do
  let(:errors) { instance_double(ActiveModel::Errors) }
  let(:model) { double }
  let(:helper) { instance_double(UspsInPersonProofing::TransliterableValidatorHelper) }
  let(:sut) do
    described_class.new(
      fields: [*UspsInPersonProofing::TransliterableValidatorHelper::SUPPORTED_FIELDS],
    )
  end

  describe '#initialize' do
    it 'throws when using unsupported fields' do
      expect do
        described_class.new(
          fields: [:abc,
                   *UspsInPersonProofing::TransliterableValidatorHelper::SUPPORTED_FIELDS, :def],
        )
      end.to raise_error(StandardError, 'Unsupported transliteration fields: ["abc","def"]')
    end

    it 'does not throw when using supported fields' do
      expect do
        sut
      end.not_to raise_error
    end
  end

  describe '#validate' do
    before(:each) do
      allow(UspsInPersonProofing::TransliterableValidatorHelper).to receive(:new).
        and_return(helper)
    end

    context 'transliteration disabled' do
      before(:each) do
        allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
          and_return(false)
      end

      it 'does not validate fields' do
        expect(helper).not_to receive(:validate)
        expect(model).not_to receive(:errors)
        sut.validate(
          model,
        )
      end
    end

    context 'transliteration enabled' do
      before(:each) do
        allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
          and_return(true)
      end

      it 'validates fields' do
        validate_input = {}
        UspsInPersonProofing::TransliterableValidatorHelper::SUPPORTED_FIELDS.each do |field|
          value = "#{field}_value"
          validate_input[field] = value
          expect(model).to receive(field).and_return(value)
        end
        expect(model).not_to receive(:errors)
        expect(helper).to receive(:validate).with(hash_including(**validate_input)).
          and_return(nil)
        sut.validate(
          model,
        )
      end

      it 'sets field errors' do
        validate_input = {}
        UspsInPersonProofing::TransliterableValidatorHelper::SUPPORTED_FIELDS.each do |field|
          value = "#{field}_value"
          validate_input[field] = value
          allow(model).to receive(field).and_return(value)
        end
        allow(helper).to receive(:validate).with(hash_including(**validate_input)).
          and_return({
            a: 'b',
            def: '1234',
            '1234': nil,
          })
        expect(model).to receive(:errors).and_return(errors).at_least(:once)
        expect(errors).to receive(:add).with(:a, :nontransliterable_field, message: 'b', pii: true)
        expect(errors).to receive(:add).with(
          :def, :nontransliterable_field, message: '1234',
                                          pii: true
        )
        expect(errors).not_to receive(:add).with(
          :'1234', :nontransliterable_field, message: nil,
                                             pii: true
        )
        sut.validate(
          model,
        )
      end
    end
  end
end
