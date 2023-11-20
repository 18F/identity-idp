module PushNotification
  # This is used for account reinstatement
  class AccountEnabledEvent
    include IssSubEvent

    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/account-enabled'.freeze

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def event_type
      EVENT_TYPE
    end
  end
end
