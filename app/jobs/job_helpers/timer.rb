# frozen_string_literal: true

require 'time'

module JobHelpers
  class Timer
    attr_reader :results

    def initialize
      @results = {}
    end

    # rubocop:disable Rails/TimeZone
    def time(name)
      start = Time.now.to_f

      yield
    ensure
      results[name] = ((Time.now.to_f - start) * 1000).round(2)
    end
    # rubocop:enable Rails/TimeZone
  end
end
