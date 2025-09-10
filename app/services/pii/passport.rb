# frozen_string_literal: true

# rubocop:disable Style/MutableConstant
module Pii
  Passport = RedactedData.define(
    :first_name,
    :last_name,
    :middle_name,
    :dob,
    :sex,
    :birth_place,
    :passport_expiration,
    :issuing_country_code,
    :mrz,
    :passport_issued,
    :nationality_code,
    :document_number,
    :document_type_received,
  ) do
    def id_doc_type
      document_type_received
    end
  end
end
# rubocop:enable Style/MutableConstant
