# frozen_string_literal: true

module UspsInPersonProofing
  PostOffice = Struct.new(
    :address,
    :city,
    :distance,
    :name,
    :saturday_hours,
    :state,
    :sunday_hours,
    :weekday_hours,
    :zip_code_4,
    :zip_code_5,
    keyword_init: true,
  )
end
