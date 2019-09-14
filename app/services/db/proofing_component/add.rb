module Db
  module ProofingComponent
    class Add
      TOKEN_WHITELIST = %i[
        document_check
        document_type
        source_check
        resolution_check
        address_check
        verified_at
      ].freeze
      # document_check: acuant
      # document_type: state_id
      # source_check: aamva
      # resolution_check: lexis_nexis
      # address_check: lexis_nexis_phone, usps

      def self.call(user_id, token, value)
        return unless user_id
        proofing_cost = ::ProofingComponent.find_or_create_by(user_id: user_id)
        return unless TOKEN_WHITELIST.index(token.to_sym)
        proofing_cost[token] = value
        proofing_cost.save
      end
    end
  end
end
