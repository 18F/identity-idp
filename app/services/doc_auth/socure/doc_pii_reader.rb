# frozen_string_literal: true

module DocAuth
  module Socure
    module DocPiiReader
      private

      # @return [Pii::StateId, nil]
      def read_pii(document_verification_data)
        document_data = document_verification_data['documentData'] || {}
        document_type = document_verification_data['documentType'] || {}
        state_id_type_slug = document_type['type']
        state_id_type = DocAuth::Response::ID_TYPE_SLUGS[state_id_type_slug]

        parsed_address = document_data['parsedAddress'] || {}

        Pii::StateId.new(
          first_name: document_data['firstName'],
          last_name: document_data['surName'],
          middle_name: nil, # doesn't appear to be available?
          address1: parsed_address['physicalAddress'],
          address2: parsed_address['physicalAddress2'],
          city: parsed_address['city'],
          state: parsed_address['state'],
          zipcode: parsed_address['zip'],
          dob: document_data['dob'] ? Date.parse(document_data['dob']) : nil,
          state_id_expiration: document_data['expirationDate'] ? Date.parse(document_data['expirationDate']) : nil,
          state_id_issued: document_data['issueDate'] ? Date.parse(document_data['issueDate']) : nil,
          state_id_jurisdiction: parsed_address['state'],
          state_id_number: document_data['documentNumber'],
          state_id_type: state_id_type,
          issuing_country_code: document_type['country'],
        )
      end
    end
  end
end
