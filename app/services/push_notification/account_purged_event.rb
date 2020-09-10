module PushNotification
  class AccountPurgedEvent
    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/account-purged'.freeze

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
      }
    end
  end
end
