module IrsAttemptsApiTrackingHelper
  class FakeAttemptsTracker

    include IrsAttemptsApi::TrackerEvents

    attr_reader :events

    def initialize
      @events = Hash.new
    end

    def track_event(event, attributes = {})
      events[event] ||= []
      events[event] << attributes
      nil
    end

    def track_mfa_submit_event(_attributes)
      # no-op
    end

    def browser_attributes
      {}
    end
  end

  RSpec::Matchers.define :have_logged_event do |event_name, attributes|
    attributes ||= {}

    match do |actual|
      expect(actual).to be_kind_of(FakeAttemptsTracker)

      if RSpec::Support.is_a_matcher?(attributes)
        expect(actual.events[event_name]).to include(attributes)
      else
        expect(actual.events[event_name]).to(be_any { |event| attributes <= event })
      end
    end

    failure_message do |actual|
      <<~MESSAGE
        Expected that FakeAttemptsTracker would have received event #{event_name.inspect}
        with #{attributes.inspect}.

        Events received:
        #{actual.events.pretty_inspect}
      MESSAGE
    end
  end
end