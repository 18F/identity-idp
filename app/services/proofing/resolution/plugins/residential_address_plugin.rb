# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      module ResidentialAddressPlugin
        def call(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          timer:
        )
          return residential_address_unnecessary_result unless ipp_enrollment_in_progress

          timer.time('residential address') do
            proofer.proof(applicant_pii)
          end.tap do |result|
            Db::SpCost::AddSpCost.call(
              current_sp,
              sp_cost_token,
              transaction_id: result.transaction_id,
            )
          end
        end

        def residential_address_unnecessary_result
          Proofing::Resolution::Result.new(
            success: true,
            errors: {},
            exception: nil,
            vendor_name: 'ResidentialAddressNotRequired',
          )
        end
      end
    end
  end
end
