# frozen_string_literal: true

require_relative 'socure'

module EventSummarizer
  module VendorResultEvaluators
    class SocurePhoneRisk < Socure
      class << self
        private

        def reason_codes(result)
          result['vendor']['result']['phonerisk']['reason_codes']
        end

        def type
          'phonerisk'
        end

        def module_name
          'Phone Risk'
        end
      end
    end
  end
end
