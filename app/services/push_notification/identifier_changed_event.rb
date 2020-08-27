module PushNotification
  class IdentifierChangedEvent
    EVENT_TYPE = 'https://schemas.openid.net/secevent/risc/event-type/identifier-recycled'

    attr_reader :user

    def initialize(user:, email:)
    end

    def event_type
      EVENT_TYPE
    end

    def payload(*)
      {
        subject: {
          subject_type: 'email',
          email: email,
        }
      }
    end
  end
end
