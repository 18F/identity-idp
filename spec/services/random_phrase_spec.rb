require 'rails_helper'

describe RandomPhrase do
  describe '#words' do
    it 'returns array of length specified in new' do
      phrase = RandomPhrase.new(num_words: 5)

      expect(phrase.words.length).to eq 5
    end
  end

  describe '#to_s' do
    it 'stringifies to space-delimited phrase' do
      phrase = RandomPhrase.new(num_words: 3, word_length: 3)

      expect(phrase.to_s).to match(/\A(\w\w\w) (\w\w\w) (\w\w\w)\z/)
    end

    it 'defaults to word length of 4' do
      phrase = RandomPhrase.new(num_words: 5)

      expect(phrase.to_s.length).to eq 24 # 20 chars + 4 spaces
    end
  end
end
