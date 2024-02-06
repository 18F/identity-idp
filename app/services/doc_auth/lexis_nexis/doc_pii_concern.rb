module DocAuth
  module LexisNexis
    module DocPiiConcern
      extend ActiveSupport::Concern

      PII_EXCLUDES = %w[
        Age
        DocSize
        DOB_Day
        DOB_Month
        DOB_Year
        ExpirationDate_Day
        ExpirationDate_Month
        ExpirationDate_Year
        FullName
        Portrait
        Sex
      ].freeze

      private

      def read_pii
        return {} unless true_id_product&.dig(:IDAUTH_FIELD_DATA).present?
        pii = {}
        PII_INCLUDES.each do |true_id_key, idp_key|
          pii[idp_key] = true_id_product[:IDAUTH_FIELD_DATA][true_id_key]
        end
        pii[:state_id_type] = DocAuth::Response::ID_TYPE_SLUGS[pii[:state_id_type]]

        dob = parse_date(
          year: pii.delete(:dob_year),
          month: pii.delete(:dob_month),
          day: pii.delete(:dob_day),
        )
        pii[:dob] = dob if dob

        exp_date = parse_date(
          year: pii.delete(:state_id_expiration_year),
          month: pii.delete(:state_id_expiration_month),
          day: pii.delete(:state_id_expiration_day),
        )
        pii[:state_id_expiration] = exp_date if exp_date

        issued_date = parse_date(
          year: pii.delete(:state_id_issued_year),
          month: pii.delete(:state_id_issued_month),
          day: pii.delete(:state_id_issued_day),
        )
        pii[:state_id_issued] = issued_date if issued_date

        pii
      end

      PII_INCLUDES = {
        'Fields_FirstName' => :first_name,
        'Fields_MiddleName' => :middle_name,
        'Fields_Surname' => :last_name,
        'Fields_AddressLine1' => :address1,
        'Fields_AddressLine2' => :address2,
        'Fields_City' => :city,
        'Fields_State' => :state,
        'Fields_PostalCode' => :zipcode,
        'Fields_DOB_Year' => :dob_year,
        'Fields_DOB_Month' => :dob_month,
        'Fields_DOB_Day' => :dob_day,
        'Fields_DocumentNumber' => :state_id_number,
        'Fields_IssuingStateCode' => :state_id_jurisdiction,
        'Fields_xpirationDate_Day' => :state_id_expiration_day, # this is NOT a typo
        'Fields_ExpirationDate_Month' => :state_id_expiration_month,
        'Fields_ExpirationDate_Year' => :state_id_expiration_year,
        'Fields_IssueDate_Day' => :state_id_issued_day,
        'Fields_IssueDate_Month' => :state_id_issued_month,
        'Fields_IssueDate_Year' => :state_id_issued_year,
        'Fields_DocumentClassName' => :state_id_type,
        'Fields_CountryCode' => :issuing_country_code,
      }.freeze

      def parse_date(year:, month:, day:)
        Date.new(year.to_i, month.to_i, day.to_i).to_s if year.to_i.positive?
      rescue ArgumentError
        message = {
          event: 'Failure to parse TrueID date',
        }.to_json
        Rails.logger.info(message)
        nil
      end
    end
  end
end
