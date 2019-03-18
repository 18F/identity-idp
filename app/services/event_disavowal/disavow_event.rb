module EventDisavowal
  class DisavowEvent
    attr_reader :event

    def initialize(event)
      @event = event
    end

    def call
      event.update!(disavowed_at: Time.zone.now)
    end
  end
end
