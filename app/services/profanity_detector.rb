# Detects profanity in a string, the list of profane words
# comes from the profanity_filter gem for now
module ProfanityDetector
  module_function

  # Calls a block until the result does not contain profanity
  # @yield block that generates a random value
  # @yieldreturn [String] string to check for profanity
  def without_profanity
    loop do
      word = yield

      return word unless profane?(word)
    end
  end

  # Returns true if the string contains profanity inside it
  # ProfanityFilter::Base.profane? splits by word, but this
  # checks all substrings
  def profane?(str)
    preprocess_if_needed!

    str_chars = str.gsub(/\W/, '').downcase.chars

    (min_profanity_length..[str_chars.length, max_profanity_length].min).each do |size|
      profane_words = @profanity_by_length[size]
      next if profane_words.empty?

      str_chars.each_cons(size) do |letters|
        return true if profane_words.include?(letters.join)
      end
    end

    false
  end

  class << self
    attr_reader :min_profanity_length
    attr_reader :max_profanity_length
  end

  def preprocess_if_needed!
    return if @preprocessed

    # Map of {Integer => Set<string>}
    @profanity_by_length = Hash.new { |h, k| h[k] = Set.new }

    ProfanityFilter::Base.dictionary.keys.each do |word|
      @profanity_by_length[word.size] << word.downcase
    end

    @min_profanity_length, @max_profanity_length = @profanity_by_length.keys.minmax

    @preprocessed = true
  end
end
