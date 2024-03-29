# frozen_string_literal: true

module PushNotification
  class RecoveryActivatedEvent
    include IssSubEvent

    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/recovery-activated'

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def event_type
      EVENT_TYPE
    end
  end
end
