class PersonalKeyFormatter
  def regexp
    char_count = RandomPhrase::WORD_LENGTH
    word_count = Figaro.env.recovery_code_length.to_i
    valid_char = '[a-zA-Z0-9]'
    regexp =
      "(?:#{valid_char}{#{char_count}}([\s-])?){#{word_count - 1}}#{valid_char}{#{char_count}}"

    regexp
  end
end
