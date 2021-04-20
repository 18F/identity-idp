module PushNotification
  class RecoveryActivatedEvent
    include IssSubEvent

    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/recovery-activated'.freeze

    attr_reader :user

    def initialize(user:)
      @user = user
    end
  end
end
