class Utf8Cleaner
  attr_reader :string

  def initialize(string)
    @string = string
  end

  def remove_invalid_utf8_bytes
    string&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
  end
end
