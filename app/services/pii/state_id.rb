# frozen_string_literal: true

# rubocop:disable Style/MutableConstant
module Pii
  StateId = RedactedData.define(
    :first_name,
    :last_name,
    :middle_name,
    :name_suffix,
    :address1,
    :address2,
    :city,
    :state,
    :zipcode,
    :dob,
    :sex,
    :height,
    :weight,
    :eye_color,
    :state_id_expiration,
    :state_id_issued,
    :state_id_jurisdiction,
    :state_id_number,
    :document_type_received,
    :issuing_country_code,
  ) do
    def id_doc_type
      document_type_received
    end

    # @returns [Boolean] Whether the document requires a residential address.
    def residential_address_required?
      state == 'PR'
    end

    # @returns [Pii::Address] The address created from the document.
    def to_pii_address
      Pii::Address.new(
        address1: address1,
        address2: address2,
        city: city,
        state: state,
        zipcode: zipcode,
      )
    end
  end
end
# rubocop:enable Style/MutableConstant
