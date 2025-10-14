# frozen_string_literal: true

module PushNotification
  # This is used for account suspension
  class AccountDisabledEvent
    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/account-disabled'

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def event_type
      EVENT_TYPE
    end

    def payload(iss:, iss_sub:)
      {
        subject: {
          subject_type: 'iss-sub',
          iss: iss,
          sub: iss_sub,
        },
        reason: 'account-suspension',
      }
    end

    def ==(other)
      self.class == other.class && user == other.user
    end
  end
end
