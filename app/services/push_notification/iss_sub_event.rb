# frozen_string_literal: true

module PushNotification
  module IssSubEvent
    def payload(iss:, iss_sub:)
      {
        subject: {
          subject_type: 'iss-sub',
          iss: iss,
          sub: iss_sub,
        },
      }
    end

    # Used by specs for argument matching
    def ==(other)
      self.class == other.class && user == other.user
    end
  end
end
