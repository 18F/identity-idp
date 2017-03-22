class RandomPhrase
  attr_reader :words

  WORD_LENGTH = 4

  def initialize(num_words:, word_length: WORD_LENGTH)
    @word_length = word_length
    @words = build_words(num_words)
  end

  def to_s
    @words.join(' ')
  end

  private

  def build_words(num_words)
    str_size = num_words * @word_length
    # 5 bits per character means we must multiply what we want by 5
    # :length adds zero padding in case it's a smaller number
    random_bytes = SecureRandom.random_number(2**(str_size * 5))
    random_string = Base32::Crockford.encode(random_bytes, length: str_size, split: @word_length)
    random_string.upcase.split('-')
  end
end
