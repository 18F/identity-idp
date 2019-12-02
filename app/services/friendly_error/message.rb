module FriendlyError
  class Message
    def self.call(message, path)
      error_key = FriendlyError::FindKey.call(message, path)
      return message if error_key.blank?
      I18n.t('friendly_errors.' + path + '.' + error_key.to_s, default: message)
    end
  end
end
