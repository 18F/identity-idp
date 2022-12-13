module UspsInPersonProofing
  Applicant = Struct.new(
    :unique_id,
    :first_name,
    :last_name,
    :address,
    :city,
    :state,
    :zip_code,
    :email,
    keyword_init: true,
  )
end
