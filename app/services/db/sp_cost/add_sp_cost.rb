module Db
  module SpCost
    class AddSpCost
      class SpCostTypeError < StandardError; end

      TOKEN_ALLOWLIST = %i[
        aamva
        acuant_front_image
        acuant_back_image
        acuant_result
        acuant_selfie
        lexis_nexis_resolution
        lexis_nexis_address
        gpo_letter
        threatmetrix
      ].freeze

      def self.call(service_provider, ial, token, transaction_id: nil, user: nil)
        return if token.blank?
        unless TOKEN_ALLOWLIST.include?(token.to_sym)
          NewRelic::Agent.notice_error(SpCostTypeError.new(token.to_s))
          return
        end
        agency_id = service_provider&.agency_id || 0
        ial_context = IalContext.new(
          ial: ial,
          service_provider: service_provider,
          user: user,
        )
        ::SpCost.create(
          issuer: service_provider&.issuer.to_s,
          ial: ial_context.bill_for_ial_1_or_2,
          agency_id: agency_id,
          cost_type: token,
          transaction_id: transaction_id,
        )
      end
    end
  end
end
