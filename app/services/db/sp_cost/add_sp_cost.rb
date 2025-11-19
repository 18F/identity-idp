# frozen_string_literal: true

module Db
  module SpCost
    class AddSpCost
      class SpCostTypeError < StandardError; end

      TOKEN_ALLOWLIST = %i[
        aamva
        acuant_front_image
        acuant_back_image
        acuant_selfie
        acuant_result
        lexis_nexis_resolution
        lexis_nexis_address
        gpo_letter
        threatmetrix
      ].freeze

      def self.call(service_provider, token, transaction_id: nil)
        return if token.blank?
        unless TOKEN_ALLOWLIST.include?(token.to_sym)
          NewRelic::Agent.notice_error(SpCostTypeError.new(token.to_s))
          return
        end
        agency_id = service_provider&.agency_id || 0
        ::SpCost.create(
          issuer: service_provider&.issuer.to_s,
          ial: 2,
          agency_id: agency_id,
          cost_type: token,
          transaction_id: transaction_id,
        )
      end
    end
  end
end
