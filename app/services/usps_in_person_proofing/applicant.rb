# frozen_string_literal: true

module UspsInPersonProofing
  Applicant = RedactedStruct.new(
    :unique_id, :first_name, :last_name, :address, :city, :state, :zip_code,
    :email, :document_type, :document_number, :document_expiration_date, keyword_init: true
  ) do
    def self.from_usps_applicant_and_enrollment(applicant, enrollment)
      self.new(
        unique_id: enrollment.unique_id,
        first_name: transliterate(applicant.first_name),
        last_name: transliterate(applicant.last_name),
        address: transliterate(applicant.address1),
        city: transliterate(applicant.city),
        state: applicant.state,
        zip_code: applicant.zipcode,
        email: IdentityConfig.store.usps_ipp_enrollment_status_update_email_address.presence,
        document_number: applicant.id_number,
        document_expiration_date: applicant.id_expiration,
        document_type: enrollment.document_type,
      )
    end

    def has_valid_address?
      (address =~ /[^A-Za-z0-9\-' .\/#]/).nil?
    end

    private

    def self.transliterate(value)
      transliterator = Transliterator.new
      result = transliterator.transliterate(value)
      if result.unsupported_chars.present?
        result.original
      else
        result.transliterated
      end
    end
  end.freeze
end
