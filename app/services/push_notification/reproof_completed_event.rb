module PushNotification
  class ReproofCompletedEvent
    include IssSubEvent

    EVENT_TYPE = 'https://schemas.login.gov/secevent/risc/event-type/reproof-completed'.freeze

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def event_type
      EVENT_TYPE
    end
  end
end
