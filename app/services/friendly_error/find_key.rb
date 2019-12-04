module FriendlyError
  class FindKey
    def self.call(message, path)
      FRIENDLY_ERROR_CONFIG[path].find { |_key, value| value == message }&.first
    end
  end
end
