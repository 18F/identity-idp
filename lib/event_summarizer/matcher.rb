# frozen_string_literal: true

module EventSummarizer
  class Matcher
    def match?(event)
      raise NotImplementedError
    end

    def format(event)
      raise NotImplementedError
    end
  end
end
