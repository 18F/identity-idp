# frozen_string_literal: true

module EventSummarizer
  class ExampleMatcher
    attr_reader :event_count

    def initialize
      @event_count = 0
    end

    def handle_cloudwatch_event(_event)
      @event_count += 1
    end

    def finish
      [
        {
          title: 'Processed some events',
          attributes: [
            { type: :event_count, description: "Processed #{event_count} event(s)" },
          ],
        }.tap do
          @event_count = 0
        end,
      ]
    end
  end
end
