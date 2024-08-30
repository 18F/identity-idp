require 'rails_helper'

RSpec.describe ReadableNumber do
  describe '.of' do
    subject(:result) { ReadableNumber.of(number) }

    context 'a number not greater than 10' do
      let(:number) { 1 }

      it 'returns the humanized number' do
        expect(result).to eq('one')
      end

      context 'in a non-English locale' do
        before do
          I18n.locale = :fr
        end

        it 'returns the translated, humanized number' do
          expect(result).to eq('un')
        end
      end

      context 'in a locale with forced numeric usage' do
        before do
          I18n.locale = ReadableNumber::FORCED_NUMERIC_LOCALES.to_a.sample
        end

        it 'returns the literal number, stringified' do
          expect(result).to eq('1')
        end
      end

      context 'in a locale without support' do
        it 'returns the literal number, stringified' do
          original_enforce_available_locales = I18n.enforce_available_locales
          original_available_locales = I18n.available_locales
          original_locale = I18n.locale
          I18n.enforce_available_locales = false
          I18n.available_locales = I18n.available_locales + [:'aa-BB']
          I18n.locale = :'aa-BB'

          expect(result).to eq('1')
        ensure
          I18n.enforce_available_locales = original_enforce_available_locales
          I18n.available_locales = original_available_locales
          I18n.locale = original_locale
        end
      end
    end

    context 'a number greater than 10' do
      let(:number) { 11 }

      it 'returns the literal number, stringified' do
        expect(result).to eq('11')
      end
    end
  end
end
