require 'rails_helper'

describe I18n do
  let(:translation_key) { 'asdf.qwert.1234' }
  let(:english_translation) { 'this is some text' }
  let(:spanish_translation) { 'NOT TRANSLATED YET' }
  let(:local_argument) { :en }

  before do
    allow(I18n.config.backend).to receive(:translate).
      with(:es, translation_key, {}).
      and_return(spanish_translation)
    allow(I18n.config.backend).to receive(:translate).
      with(:en, translation_key, {}).
      and_return(english_translation)
  end

  after do
    I18n.locale = :en
  end

  describe '#translate' do
    context 'with non-english locale' do
      context 'when the requested string is untranslated' do
        it 'should return the english translation with a locale argument' do
          expect(I18n.t('asdf.qwert.1234', locale: :es)).to eq(english_translation)
        end

        it 'should return the english translation with a global locale' do
          I18n.locale = :es

          expect(I18n.t('asdf.qwert.1234')).to eq(english_translation)
        end
      end

      context 'when the requested string is translated' do
        let(:spanish_translation) { 'esto es un texto' }

        it 'should return the non-english translation with a locale argument' do
          expect(I18n.t('asdf.qwert.1234', locale: :es)).to eq(spanish_translation)
        end

        it 'should return the non-english translation with a global locale' do
          I18n.locale = :es

          expect(I18n.t('asdf.qwert.1234')).to eq(spanish_translation)
        end
      end
    end

    context 'with english locale' do
      it 'should return the english translation with a locale argument' do
        expect(I18n.t('asdf.qwert.1234', locale: :en)).to eq(english_translation)
      end

      it 'should return the english translation with a global locale' do
        expect(I18n.t('asdf.qwert.1234')).to eq(english_translation)
      end
    end

    context 'when english translation is "NOT TRANSLATED YET"' do
      let(:english_translation) { 'NOT TRANSLATED YET' }

      it 'does not recurse with a locale argument' do
        expect(I18n.t('asdf.qwert.1234', locale: :en)).to eq('NOT TRANSLATED YET')
      end

      it 'does not recurse without a locale argument' do
        expect(I18n.t('asdf.qwert.1234')).to eq('NOT TRANSLATED YET')
      end
    end
  end
end
