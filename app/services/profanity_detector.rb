# Detects profanity in a string, the list of profane words
# comes from the profanity_filter gem for now
module ProfanityDetector
  module_function

  # Calls a block until the result does not contain profanity
  # @yield block that generates a random value
  # @yieldreturn [String] string to check for profanity
  def without_profanity(limit: 1_000)
    limit.times do
      word = yield

      return word unless profane?(word)
    end

    raise 'random generator limit'
  end

  # Returns true if the string contains profanity inside it
  # ProfanityFilter::Base.profane? splits by word, but this
  # checks all substrings
  def profane?(str)
    str_no_whitespace = str.gsub(/\W/, '').downcase

    (MIN_PROFANITY_LENGTH..[str_no_whitespace.length, MAX_PROFANITY_LENGTH].min).each do |size|
      profane_regex = REGEX_BY_LENGTH[size]
      next if profane_regex.nil?
      return true if profane_regex.match?(str_no_whitespace)
    end

    false
  end

  def self.preprocess_lengths!
    # Map of {Integer => Set<string>}
    profanity_by_length = Hash.new { |h, k| h[k] = Set.new }

    ProfanityFilter::Base.dictionary.keys.each do |word|
      profanity_by_length[word.size] << word.downcase
    end

    # Map of {Integer => Regexp}
    regex_by_length = Hash.new

    profanity_by_length.each do |k, v|
      escaped = v.to_a.map { |x| Regexp.escape(x) }
      regex_by_length[k] = Regexp.new("(#{escaped.join('|')})")
    end

    min_profanity_length, max_profanity_length = profanity_by_length.keys.minmax

    return [regex_by_length, min_profanity_length, max_profanity_length]
  end

  REGEX_BY_LENGTH, MIN_PROFANITY_LENGTH, MAX_PROFANITY_LENGTH = self.preprocess_lengths!
end
