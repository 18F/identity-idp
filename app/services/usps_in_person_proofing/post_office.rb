module UspsInPersonProofing
  PostOffice = Struct.new(
    :distance, :address, :city, :phone, :name, :zip_code, :state, keyword_init: true
  )
end
