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
    random_string = SecureRandom.base64(str_size).gsub(%r{[0o+\/=]}, ('A'..'Z').to_a.sample)
    random_string.upcase[0..(str_size - 1)].chars.each_slice(@word_length).map(&:join)
  end
end
