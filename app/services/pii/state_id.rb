# frozen_string_literal: true

# rubocop:disable Style/MutableConstant
module Pii
  StateId = RedactedData.define(
    :first_name,
    :last_name,
    :middle_name,
    :address1,
    :address2,
    :city,
    :state,
    :dob,
    :state_id_expiration,
    :state_id_issued,
    :state_id_jurisdiction,
    :state_id_number,
    :state_id_type,
    :zipcode,
    :issuing_country_code,
  )
end
# rubocop:enable Style/MutableConstant
