class RandomPhrase
  attr_reader :words

  def self.load_dictionary
    IO.readlines("#{Rails.root}/config/us-constitution.lexicon").map(&:chomp)
  end

  cattr_reader :dictionary do
    load_dictionary
  end

  def initialize(num_words)
    @words = dictionary.sample(num_words, random: SecureRandom)
  end

  def to_s
    @words.join(' ')
  end
end
