# frozen_string_literal: true

# Helper for generating and normalizing random strings, that can be formatted as groups of 4 letters
class RandomPhrase
  attr_reader :words, :separator

  WORD_LENGTH = 4

  def initialize(num_words:, word_length: WORD_LENGTH, separator: ' ')
    @word_length = word_length
    @words = build_words(num_words)
    @separator = separator
  end

  def to_s
    @words.join(separator)
  end

  def self.format(str, separator: ' ')
    normalize(str).
      chars.each_slice(WORD_LENGTH).map(&:join).join(separator).
      upcase
  end

  def self.normalize(str, num_words: nil)
    str = str.gsub(/\W/, '').tr('-', '').downcase.strip

    decoded = Base32::Crockford.decode(str)

    if decoded
      Base32::Crockford.encode(
        decoded,
        length: num_words ? (num_words * WORD_LENGTH) : str.length,
      ).downcase
    else
      # strings that are invalid Crockford encodings but may still be valid
      str
    end
  end

  private

  def build_words(num_words)
    str_size = num_words * @word_length
    random_string = ProfanityDetector.without_profanity do
      # 5 bits per character means we must multiply what we want by 5
      # :length adds zero padding in case it's a smaller number
      random_bytes = SecureRandom.random_number(2 ** (str_size * 5))
      Base32::Crockford.encode(random_bytes, length: str_size, split: @word_length)
    end
    random_string.upcase.split('-')
  end
end
