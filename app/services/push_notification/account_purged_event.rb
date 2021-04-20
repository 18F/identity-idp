module PushNotification
  class AccountPurgedEvent
    include IssSubEvent

    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/account-purged'.freeze

    attr_reader :user

    def initialize(user:)
      @user = user
    end
  end
end
