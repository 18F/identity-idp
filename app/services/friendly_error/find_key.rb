module FriendlyError
  class FindKey
    def self.call(message, path)
      return message_key(message, path) || 'general_error'
    end

    def self.message_key(message, path)
      FRIENDLY_ERROR_CONFIG[path].find{ |key, value| value == message }&.first
    end
    private_class_method :message_key
  end
end