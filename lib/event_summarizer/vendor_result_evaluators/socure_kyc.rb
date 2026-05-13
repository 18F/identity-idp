# frozen_string_literal: true

require_relative 'socure'

module EventSummarizer
  module VendorResultEvaluators
    class SocureKyc < Socure
      class << self
        private

        def reason_codes(result)
          result['reason_codes']
        end

        def type
          'kyc'
        end

        def module_name
          'KYC'
        end
      end
    end
  end
end
