# frozen_string_literal: true

module StringRedacter
  module_function

  def redact_alphanumeric(text)
    text.gsub(/[a-z]/i, 'X').gsub(/\d/i, '#')
  end
end
