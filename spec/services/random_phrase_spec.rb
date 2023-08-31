require 'rails_helper'

RSpec.describe RandomPhrase do
  describe '#initialize' do
    it 'checks for profanity and regenerates a random number when it finds' do
      profane = Base32::Crockford.decode('FART')
      not_profane = Base32::Crockford.decode('ABCD')

      expect(SecureRandom).to receive(:random_number).
        and_return(profane, not_profane)

      phrase = RandomPhrase.new(num_words: 1)

      expect(phrase.words).to eq(['ABCD'])
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

    it 'does not contain the letters I L O U' do
      arbitrary_largish_number = 100
      arbitrary_largish_number.times do
        phrase = RandomPhrase.new(num_words: 4)

        expect(phrase.to_s).to_not match(/[ILOU]/)
      end
    end
  end
end
