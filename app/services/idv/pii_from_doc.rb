module Idv
  PiiFromDoc = RedactedData.define(
    :address1,
    :address2,
    :city,
    :dob,
    :first_name,
    :last_name,
    :middle_name,
    :state,
    :state_id_expiration,
    :state_id_issued,
    :state_id_jurisdiction,
    :state_id_number,
    :state_id_type,
    :zipcode,
  )
end
