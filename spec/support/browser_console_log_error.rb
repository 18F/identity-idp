class BrowserConsoleLogError < StandardError
  def initialize(messages)
    @messages = messages
  end

  def to_s
    "Unexpected browser console logging:\n\n#{@messages.join("\n\n")}"
  end
end
