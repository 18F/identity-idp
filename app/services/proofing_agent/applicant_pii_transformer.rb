# frozen_string_literal: true

module ProofingAgent
  class ApplicantPiiTransformer
    def initialize(proof_params)
      @pii = proof_params.symbolize_keys
    end

    def transform
      flat = required_fields
      flat.merge!(residential_address_fields)
      flat.merge!(state_id_fields)
      flat.merge!(passport_fields)
      flat[:same_address_as_id] = same_address_as_id
      flat
    end

    private

    attr_reader :pii

    def required_fields
      {
        first_name: pii[:first_name],
        last_name: pii[:last_name],
        dob: pii[:dob],
        ssn: pii[:ssn],
        phone: pii[:phone],
        email: pii[:email],
        suspected_fraud: pii[:suspected_fraud],
        document_type_received: pii[:id_type],
      }
    end

    def residential_address_fields
      address = pii[:residential_address]
      return {} if address.blank?

      {
        address1: address[:address1],
        address2: address[:address2],
        city: address[:city],
        state: address[:state],
        zipcode: address[:zip_code],
      }
    end

    def state_id_fields
      state_id = pii[:state_id]
      return {} if state_id.blank?

      {
        state_id_number: state_id[:document_number],
        state_id_jurisdiction: state_id[:jurisdiction],
        state_id_expiration: state_id[:expiration_date],
        state_id_issued: state_id[:issue_date],
        identity_doc_address1: state_id[:address1],
        identity_doc_address2: state_id[:address2],
        identity_doc_city: state_id[:city],
        identity_doc_address_state: state_id[:state],
        identity_doc_zipcode: state_id[:zip_code],
      }
    end

    def passport_fields
      passport = pii[:passport]
      return {} if passport.blank?

      {
        passport_expiration: passport[:expiration_date],
        passport_issued: passport[:issue_date],
        issuing_country_code: passport[:issuing_country_code],
        mrz: passport[:mrz],
      }
    end

    def same_address_as_id
      pii[:residential_address].present? ? 'false' : 'true'
    end
  end
end
