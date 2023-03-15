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
    :is_pilot,
    keyword_init: true,
  )
end
