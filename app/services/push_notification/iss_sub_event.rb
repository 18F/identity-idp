module PushNotification
  module IssSubEvent
    def payload(iss_sub:)
      {
        subject: {
          subject_type: 'iss-sub',
          iss: Rails.application.routes.url_helpers.root_url,
          sub: iss_sub,
        },
      }
    end

    # Used by specs for argument matching
    def ==(other)
      self.class == other.class && user == other.user
    end

    def event_type
      self.class::EVENT_TYPE
    end
  end
end
