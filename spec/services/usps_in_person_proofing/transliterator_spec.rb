require 'rails_helper'

RSpec.describe UspsInPersonProofing::Transliterator do
  describe '#transliterate' do
    context 'baseline functionality' do
      let(:inputValue) { "\t\n BobИy \t   TЉbles\r\n" }
      let(:sut) { UspsInPersonProofing::Transliterator.new }
      let(:result) { sut.transliterate(:inputValue) }

      it 'strips whitespace from the ends' do
        expect(result.transliterated).not_to match(/^\s+/)
        expect(result.transliterated).not_to match(/\s+^/)
      end
      it 'replaces consecutive whitespaces with regular spaces' do
        expect(result.transliterated).not_to match(/\s\s/)
        expect(result.transliterated).not_to match(/[^\S ]+/)
      end
      it 'returns a list of the characters that transliteration does not support' do
        expect(result.unsupported_chars).to eq(['И', 'Љ'])
      end
      it 'transliterates using English locale when default does not match' do
        expect(I18n).to receive(:transliterate).with(locale: :en)
        result
      end
      it 'does not count question marks as unsupported characters by default' do
      end
      it 'returns a shorthand for determining when transliteration changed the value'
      it 'returns the original value that was requested to be transliterated'
    end

    it 'converts additional values not supported for transliteration by default' do
    end
  end
end
