require 'rails_helper'

RSpec.describe UspsInPersonProofing::Transliterator do
  describe '#transliterate' do
    context 'baseline functionality' do
      let(:sut) { UspsInPersonProofing::Transliterator.new }
      let(:inputValue) { "\t\n BobИy \t   TЉble?s\r\n" }
      let(:result) { sut.transliterate(inputValue) }
      let(:transliteratedResult) { 'Bob?y T?ble?s' }

      let(:inputValue2) { 'Abc Is My Fav Number' }
      let(:result2) { sut.transliterate(inputValue2) }
      let(:transliteratedResult2) { inputValue2 }

      it 'strips whitespace from the ends' do
        expect(result.transliterated).not_to match(/^\s+/)
        expect(result.transliterated).not_to match(/\s+^/)
      end
      it 'replaces consecutive whitespaces with regular spaces' do
        expect(result.transliterated).not_to match(/\s\s/)
        expect(result.transliterated).not_to match(/[^\S ]+/)
      end
      it 'returns a list of the characters that transliteration does not support' do
        expect(result.unsupported_chars).to include('И', 'Љ')
      end
      it 'transliterates using English locale when default does not match' do
        expect(I18n).to receive(:transliterate).
          with(duck_type(:to_s), locale: :en).
          and_call_original
        result
      end
      it 'does not count question marks as unsupported characters by default' do
        expect(result.unsupported_chars).not_to include('?')
        expect(result.transliterated).to include('?')
      end
      it 'returns a shorthand for determining when transliteration changed the value' do
        expect(result.changed?).to be(true)
        expect(result2.changed?).to be(false)
      end
      it 'returns the original value that was requested to be transliterated' do
        expect(result.original).to eq(inputValue)
        expect(result2.original).to eq(inputValue2)
      end
      it 'returns the expected transliterated value for the examples' do
        expect(result.transliterated).to eq(transliteratedResult)
        expect(result2.transliterated).to eq(transliteratedResult2)
      end
    end

    context 'for additional values not supported for transliteration by default' do
      {
        # Convert okina to apostrophe
        "ʻ": "'",
        # Convert quotation marks
        "’": "'",
        "‘": "'",
        "‛": "'",
        "“": '"',
        "‟": '"',
        "”": '"',
        # Convert hyphens
        "‐": '-',
        "‑": '-',
        "‒": '-',
        "–": '-',
        "—": '-',
        "﹘": '-',
        # Convert number signs
        "﹟": '#',
        "＃": '#',
      }.each do |key, value|
        it "converts \"\\u#{key.to_s.ord.to_s(16).rjust(
          4,
          '0',
        )}\" to \"\\u#{value.ord.to_s(16).rjust(
          4, '0'
        )}\"" do
          expect(sut.transliterate(key)).to eq(value)
        end
      end
    end
  end
end
