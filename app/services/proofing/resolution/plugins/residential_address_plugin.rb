# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class ResidentialAddressPlugin
        def call(applicant_pii:, ipp_enrollment_in_progress:, timer:, proofer:)
          return residential_address_unnecessary_result unless ipp_enrollment_in_progress

          timer.time('residential address') do
            proofer.proof(applicant_pii)
          end
        end

        def residential_address_unnecessary_result
          Proofing::Resolution::Result.new(
            success: true, errors: {}, exception: nil, vendor_name: 'ResidentialAddressNotRequired',
          )
        end
      end
    end
  end
end
