module PushNotification
  class MfaLimitAccountLockedEvent
    include IssSubEvent

    EVENT_TYPE =
      'https://schemas.login.gov/secevent/risc/event-type/mfa-limit-account-locked'.freeze

    attr_reader :user

    def initialize(user:)
      @user = user
    end
  end
end
