# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module DocPiiReader
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

      # @return [Pii::StateId, nil]
      def read_pii(true_id_product)
        id_auth_field_data = true_id_product&.dig(:IDAUTH_FIELD_DATA)
        return nil unless id_auth_field_data.present?

        state_id_type_slug = id_auth_field_data['Fields_DocumentClassName']
        state_id_type = DocAuth::Response::ID_TYPE_SLUGS[state_id_type_slug]

        Pii::StateId.new(
          first_name: id_auth_field_data['Fields_FirstName'],
          last_name: id_auth_field_data['Fields_Surname'],
          middle_name: id_auth_field_data['Fields_MiddleName'],
          name_suffix: id_auth_field_data['Fields_NameSuffix'],
          address1: id_auth_field_data['Fields_AddressLine1'],
          address2: id_auth_field_data['Fields_AddressLine2'],
          city: id_auth_field_data['Fields_City'],
          state: id_auth_field_data['Fields_State'],
          zipcode: id_auth_field_data['Fields_PostalCode'],
          dob: parse_date(
            year: id_auth_field_data['Fields_DOB_Year'],
            month: id_auth_field_data['Fields_DOB_Month'],
            day: id_auth_field_data['Fields_DOB_Day'],
          ),
          state_id_expiration: parse_date(
            year: id_auth_field_data['Fields_ExpirationDate_Year'],
            month: id_auth_field_data['Fields_ExpirationDate_Month'],
            day: id_auth_field_data['Fields_xpirationDate_Day'], # this is NOT a typo
          ),
          state_id_issued: parse_date(
            year: id_auth_field_data['Fields_IssueDate_Year'],
            month: id_auth_field_data['Fields_IssueDate_Month'],
            day: id_auth_field_data['Fields_IssueDate_Day'],
          ),
          state_id_jurisdiction: id_auth_field_data['Fields_IssuingStateCode'],
          state_id_number: id_auth_field_data['Fields_DocumentNumber'],
          state_id_type: state_id_type,
          issuing_country_code: id_auth_field_data['Fields_CountryCode'],
        )
      end

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
