# frozen_string_literal: true

module PushNotification
  class PasswordResetEvent
    include IssSubEvent

    EVENT_TYPE = 'https://schemas.login.gov/secevent/risc/event-type/password-reset'

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def event_type
      EVENT_TYPE
    end
  end
end
