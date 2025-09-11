# frozen_string_literal: true

module Pii
  UspsApplicant = RedactedStruct.new(
    :first_name, :last_name, :address1, :address2, :city, :state, :zipcode,
    :current_address_same_as_id, :id_number, :id_expiration_date, keyword_init: true
  ) do
    def self.from_pii(pii)
      new(
        first_name: pii['first_name'],
        last_name: pii['last_name'],
        id_expiration_date: pii['state_id_expiration_date'],
        id_number: pii['state_id_number'],
        address1: pii['identity_doc_address1'],
        address2: pii['identity_doc_address2'],
        city: pii['identity_doc_city'],
        state: pii['identity_doc_address_state'],
        zipcode: pii['identity_doc_zipcode'],
        current_address_same_as_id: pii['same_address_as_id'],
      )
    end

    def secondary_address_present?
      address2.present?
    end
  end.freeze
end
