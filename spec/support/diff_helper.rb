module DiffHelper
  def assert_error_messages_equal(err, expected)
    actual = normalize_error_message(err.message)
    expected = normalize_error_message(expected)
    expect(actual).to eql(expected)
  end

  def normalize_error_message(message)
    message
      .gsub(/\x1b\[[0-9;]*m/, '') # Strip ANSI control characters used for color
      .gsub(/:0x[0-9a-f]{16}/, ':<id>')
      .strip
  end
end
