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
        authentication_result_field_data = true_id_product&.dig(:AUTHENTICATION_RESULT)
        return nil unless id_auth_field_data.present?

        state_id_type_slug = id_auth_field_data['Fields_DocumentClassName']
        state_id_type = DocAuth::Response::ID_TYPE_SLUGS[state_id_type_slug]

        if state_id_type == 'drivers_license' || state_id_type == 'state_id_card'
          generate_state_id_pii(id_auth_field_data, state_id_type)
        elsif state_id_type == 'passport'
          generate_passport_pii(id_auth_field_data, state_id_type)
        end
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

      def parse_sex_value(sex_attribute)
        # A value of "non-binary" or "not-specified" may appear on a document. However, at this time
        # the DLDV `PersonSexCode` input can only process values that correspond to "male" or
        # "female".
        #
        # From the DLDV User Guide Version 2.1 - 28:
        #
        #     Since 2017, a growing number of states have allowed a person to select "not specified"
        #     or "non-binary" for their sex on the application for a credential. While Male and
        #     Female can be verified, the non-binary value cannot be verified at this time.
        #
        # This code will return `nil` for those cases with the intent that they will not be verified
        # against the DLDV where they will not be recognized
        #
        case sex_attribute
        when 'Male'
          'male'
        when 'Female'
          'female'
        end
      end

      def parse_height_value(height_attribute)
        height_match_data = height_attribute&.match(/(?<feet>\d)' ?(?<inches>\d{1,2})"/)

        return unless height_match_data

        height_match_data[:feet].to_i * 12 + height_match_data[:inches].to_i
      end

      def generate_state_id_pii(id_auth_field_data, state_id_type)
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
          sex: parse_sex_value(authentication_result_field_data&.[]('Sex')),
          height: parse_height_value(id_auth_field_data['Fields_Height']),
          weight: nil,
          eye_color: nil,
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

      def generate_passport_pii(id_auth_field_data, state_id_type)
        Pii::Passport.new(
          first_name: id_auth_field_data['Fields_FirstName'],
          last_name: id_auth_field_data['Fields_Surname'],
          city: id_auth_field_data['Fields_City'],
          state: id_auth_field_data['Fields_State'],
          dob: parse_date(
            year: id_auth_field_data['Fields_DOB_Year'],
            month: id_auth_field_data['Fields_DOB_Month'],
            day: id_auth_field_data['Fields_DOB_Day'],
          ),
          birth_place: id_auth_field_data['Fields_BirthPlace'],
          weight: nil, # TODO: check if needed
          eye_color: nil, # TODO: check if needed
          passport_expiration: parse_date(
            year: id_auth_field_data['Fields_ExpirationDate_Year'],
            month: id_auth_field_data['Fields_ExpirationDate_Month'],
            day: id_auth_field_data['Fields_xpirationDate_Day'], # this is NOT a typo
          ),
          passport_issued: parse_date(
            year: id_auth_field_data['Fields_IssueDate_Year'],
            month: id_auth_field_data['Fields_IssueDate_Month'],
            day: id_auth_field_data['Fields_IssueDate_Day'],
          ),
          state_id_type: state_id_type,
          issuing_country_code: id_auth_field_data['Fields_CountryCode'],
          nationality_code: id_auth_field_data['Fields_NationalityCode'],
          personal_number: id_auth_field_data['Fields_PersonalNumber'],
          mrz: id_auth_field_data['Fields_MRZ'],
        )
      end
    end
  end
end
