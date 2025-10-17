# frozen_string_literal: true

module Pii
  UspsApplicant = RedactedStruct.new(
    :first_name, :last_name, :address1, :address2, :city, :state, :zipcode,
    :current_address_same_as_id, :id_number, :id_expiration, keyword_init: true
  ) do
    def self.from_idv_applicant(applicant)
      new(
        first_name: applicant['first_name'],
        last_name: applicant['last_name'],
        address1: applicant['identity_doc_address1'],
        address2: applicant['identity_doc_address2'],
        city: applicant['identity_doc_city'],
        state: applicant['identity_doc_address_state'],
        zipcode: applicant['identity_doc_zipcode'],
        id_expiration: applicant['state_id_expiration'],
        id_number: applicant['state_id_number'],
        current_address_same_as_id: applicant['same_address_as_id'],
      )
    end

    def address_line2_present?
      address2.present?
    end
  end.freeze
end
