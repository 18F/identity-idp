module PushNotification
  class MfaLimitAccountLockedEvent
    EVENT_TYPE =
      'https://schemas.login.gov/secevent/risc/event-type/mfa-limit-account-locked'.freeze

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

    # Used by specs for argument matching
    def ==(other)
      user == other.user
    end
  end
end
