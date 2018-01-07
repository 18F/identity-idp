class WildcardPatternMatcher
  PatAndStrPointers = Struct.new(:pat, :str, :pat_i, :str_i)

  # pattern is a string or array of strings that can contain non-consecutive asterisks/wildcards
  def self.match?(pat, str)
    return false unless pat && str
    return match_any?(pat, str) if pat.class == Array
    ps = PatAndStrPointers.new(pat, str, 0, 0)
    match_ps?(ps)
  end

  # private

  def self.match_any?(pats, str)
    pats.each do |pat|
      return true if WildcardPatternMatcher.match?(pat, str)
    end
    false
  end

  def self.match_ps?(ps)
    return true if nothing_left_to_compare(ps)
    return false if char_after_wildcard_and_str_done(ps)
    pat_ch = ps.pat[ps.pat_i]
    return recursive_compare_next_chars(ps) if pat_ch == ps.str[ps.str_i]
    return recursive_compare_next_char_from_pat_or_str(ps) if pat_ch == '*'
    false
  end

  def self.nothing_left_to_compare(ps)
    !ps.pat[ps.pat_i] && !ps.str[ps.str_i]
  end

  def self.char_after_wildcard_and_str_done(ps)
    pat_i = ps.pat_i
    pat = ps.pat
    pat[pat_i] == '*' && pat[pat_i + 1] && !ps.str[ps.str_i]
  end

  def self.recursive_compare_next_chars(ps)
    next_ps = ps.dup
    next_ps.pat_i += 1
    next_ps.str_i += 1
    match_ps?(next_ps)
  end

  def self.recursive_compare_next_char_from_pat_or_str(ps)
    pat_ps = ps.dup
    str_ps = pat_ps.dup
    pat_ps.pat_i += 1
    return true if match_ps?(pat_ps)
    str_ps.str_i += 1
    match_ps?(str_ps)
  end

  private_class_method :match_ps?, :nothing_left_to_compare, :char_after_wildcard_and_str_done,
                       :recursive_compare_next_chars, :recursive_compare_next_char_from_pat_or_str,
                       :match_any?
end

# code above (rubocop/reek friendly) implements following 5 line alogrithm:
# return true if !pat[pat_i] && !str[str_i]
# return false if pat[pat_i] == '*' && pat[pat_i + 1] && !str[str_i]
# return match?(pat, str, pat_i + 1, str_i + 1) if pat[pat_i] == str[str_i]
# return match?(pat, pat_i + 1, str, str_i) ||
#        match?(pat, pat_i, str, str_i + 1) if pat[pat_i] == '*'
# false
