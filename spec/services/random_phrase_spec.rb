require 'rails_helper'

describe RandomPhrase do
  describe '#words' do
    it 'returns array of length specified in new' do
      phrase = RandomPhrase.new(5)

      expect(phrase.words.length).to eq 5
    end
  end

  describe '#to_s' do
    it 'stringifies to space-delimited phrase' do
      phrase = RandomPhrase.new(3)

      expect(phrase.to_s).to match(/\A(\w+) (\w+) (\w+)\z/)
    end
  end
end
