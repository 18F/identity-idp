# frozen_string_literal: true

# rubocop:disable Style/MutableConstant
module Pii
  Passport = RedactedData.define(
    :first_name,
    :last_name,
    :dob,
    :sex,
    :birth_place,
    :passport_expiration,
    :issuing_country_code,
    :mrz,
    :passport_issued,
    :nationality_code,
    :personal_number,
    :state_id_type,
  )
end
# rubocop:enable Style/MutableConstant
