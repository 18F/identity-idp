# frozen_string_literal: true

module UspsInPersonProofing
  Applicant = Struct.new(
    :unique_id, :first_name, :last_name, :address, :city, :state, :zip_code,
    :email, :document_type, :document_number, :document_expiration_date, keyword_init: true
  ) do
    def has_valid_address?
      (address =~ /[^A-Za-z0-9\-' .\/#]/).nil?
    end
  end
end
