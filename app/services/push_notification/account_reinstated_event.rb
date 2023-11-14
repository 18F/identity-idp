module PushNotification
  class AccountReinstatedEvent
    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/account-reinstated'.freeze

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def event_type
      EVENT_TYPE
    end

    def payload(*)
      {
        subject: {
          subject_type: 'account-suspension',
        },
      }
    end

    def ==(other)
      self.class == other.class && user == other.user
    end
  end
end
