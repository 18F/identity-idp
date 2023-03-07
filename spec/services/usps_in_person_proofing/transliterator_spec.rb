require 'rails_helper'

RSpec.describe UspsInPersonProofing::Transliterator do
  describe '#transliterate' do
    subject(:transliterator) { UspsInPersonProofing::Transliterator.new }
    context 'baseline functionality' do
      context 'with an input that requires transliteration' do
        let(:input_value) { "\t\n BobИy \t   TЉble?s\r\n" }
        let(:result) { transliterator.transliterate(input_value) }
        let(:transliterated_result) { 'Bob?y T?ble?s' }

        it 'returns the original value that was requested to be transliterated' do
          expect(result.original).to eq(input_value)
        end
        it 'includes a "changed?" key indicating that transliteration did change the value' do
          expect(result.changed?).to be(true)
        end
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
        it 'returns the transliterated value' do
          expect(result.transliterated).to eq(transliterated_result)
        end
      end
      context 'with an input that does not require transliteration' do
        let(:input_value) { 'Abc Is My Fav Number' }
        let(:result) { transliterator.transliterate(input_value) }

        it 'returns the original value that was requested to be transliterated' do
          expect(result.original).to eq(input_value)
        end
        it 'includes a "changed?" key indicating that transliteration did not change the value' do
          expect(result.changed?).to be(false)
        end

        it 'transliterated value is identical to the original value' do
          expect(result.transliterated).to eq(input_value)
        end
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
          expect(transliterator.transliterate(key).transliterated).to eq(value)
        end
      end
    end
  end
end
