module StringRedacter
  extend ActiveSupport::Concern

  def redact_alphanumeric(text)
    text.gsub(/[a-z]/i, 'X').gsub(/\d/i, '#')
  end
end
