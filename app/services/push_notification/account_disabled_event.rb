module PushNotification
  # This is used for account suspension
  class AccountDisabledEvent
    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/account-disabled'.freeze

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def event_type
      EVENT_TYPE
    end

    def payload(iss_sub:)
      {
        subject: {
          subject_type: 'iss-sub',
          iss: Rails.application.routes.url_helpers.root_url,
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
