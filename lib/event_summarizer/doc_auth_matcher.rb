# frozen_string_literal: true

require 'event_summarizer/matcher'
require 'byebug'

module EventSummarizer
  class DocAuthMatcher < Matcher
    def match?(event)
      ['IdV: doc auth image upload vendor submitted'].include? event['name']
    end

    def format(event)
      timestamp = DateTime.parse(event['@timestamp']).strftime('%Y-%m-%d %H:%M:%S')
      msg = JSON.parse(event['@message'])
      event_properties = msg['properties']['event_properties'].symbolize_keys
      if event_properties[:success]
        "#{timestamp}: User passed Doc Auth"
      else
        "#{timestamp}: User FAILED Doc Auth"
      end
    end
  end
end
