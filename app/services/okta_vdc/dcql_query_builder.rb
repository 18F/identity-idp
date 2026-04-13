# frozen_string_literal: true

module OktaVdc
  class DcqlQueryBuilder
    MDL_DOCTYPE = 'org.iso.18013.5.1.mDL'
    MDL_NAMESPACE = 'org.iso.18013.5.1'

    IDENTITY_CLAIMS = %w[
      given_name
      family_name
      birth_date
      document_number
      resident_address
      resident_city
      resident_state
      resident_postal_code
      issue_date
      expiry_date
      issuing_authority
    ].freeze

    def self.build
      new.build
    end

    def build
      {
        credentials: [
          {
            id: 'identity-verification',
            format: 'mso_mdoc',
            meta: {
              doctype_value: MDL_DOCTYPE,
            },
            claims: IDENTITY_CLAIMS.map do |claim|
              {
                path: [MDL_NAMESPACE, claim],
                intent_to_retain: false,
              }
            end,
          },
        ],
      }
    end
  end
end
