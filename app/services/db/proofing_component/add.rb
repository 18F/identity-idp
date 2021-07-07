module Db
  module ProofingComponent
    class Add
      TOKEN_ALLOWLIST = %i[
        address_check
        document_check
        document_type
        liveness_check
        resolution_check
        source_check
        verified_at
      ].freeze
      # address_check: lexis_nexis_phone, usps
      # document_check: acuant
      # document_type: state_id
      # liveness_check: acuant
      # resolution_check: lexis_nexis
      # source_check: aamva

      def self.call(user_id, token, value)
        return unless user_id
        proofing_cost = ::ProofingComponent.find_or_create_by(user_id: user_id)
        return unless TOKEN_ALLOWLIST.index(token.to_sym)
        proofing_cost[token] = value
        proofing_cost.save
      end
    end
  end
end
