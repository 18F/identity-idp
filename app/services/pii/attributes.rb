module Pii
  Attributes = Struct.new(
    :first_name, :middle_name, :last_name,
    :address1, :address2, :city, :state, :zipcode,
    :ssn, :dob, :phone
  ) do
    def self.new_from_hash(hash)
      attrs = new
      hash.each { |key, val| attrs[key] = val }
      attrs
    end
  end
end
