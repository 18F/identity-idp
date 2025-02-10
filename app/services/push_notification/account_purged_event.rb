# frozen_string_literal: true

module PushNotification
  class AccountPurgedEvent
    include IssSubEvent

    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/account-purged'

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def event_type
      EVENT_TYPE
    end
  end
end
