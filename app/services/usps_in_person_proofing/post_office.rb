module UspsInPersonProofing
  PostOffice = Struct.new(
    :address,
    :city,
    :distance,
    :name,
    :phone,
    :saturday_hours,
    :state,
    :sunday_hours,
    :tty,
    :weekday_hours,
    :zip_code_4,
    :zip_code_5,
    keyword_init: true,
  )
end
