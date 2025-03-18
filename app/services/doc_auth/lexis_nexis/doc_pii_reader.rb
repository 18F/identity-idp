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

      # @return [Pii::StateId, Pii::Passport, nil]
      def read_pii(true_id_product)
        @id_auth_field_data = true_id_product&.dig(:IDAUTH_FIELD_DATA)
        @authentication_result_field_data = true_id_product&.dig(:AUTHENTICATION_RESULT)
        return nil unless id_auth_field_data.present?

        state_id_type_slug = id_auth_field_data['Fields_DocumentClassName']
        @state_id_type = DocAuth::Response::ID_TYPE_SLUGS[state_id_type_slug]

        if state_id_type == 'drivers_license' || state_id_type == 'state_id_card'
          generate_state_id_pii
        elsif state_id_type == 'passport'
          generate_passport_pii
        end
      end

      def id_auth_field_data
        @id_auth_field_data
      end

      def state_id_type
        @state_id_type
      end

      def authentication_result_field_data
        @authentication_result_field_data
      end

      def first_name
        id_auth_field_data['Fields_FirstName']
      end

      def last_name
        id_auth_field_data['Fields_Surname']
      end

      def middle_name
        id_auth_field_data['Fields_MiddleName']
      end

      def dob
        parse_date(
          year: id_auth_field_data['Fields_DOB_Year'],
          month: id_auth_field_data['Fields_DOB_Month'],
          day: id_auth_field_data['Fields_DOB_Day'],
        )
      end

      def expiration_date
        parse_date(
          year: id_auth_field_data['Fields_ExpirationDate_Year'],
          month: id_auth_field_data['Fields_ExpirationDate_Month'],
          day: id_auth_field_data['Fields_xpirationDate_Day'], # this is NOT a typo
        )
      end

      def issue_date
        parse_date(
          year: id_auth_field_data['Fields_IssueDate_Year'],
          month: id_auth_field_data['Fields_IssueDate_Month'],
          day: id_auth_field_data['Fields_IssueDate_Day'],
        )
      end

      def issuing_country_code
        id_auth_field_data['Fields_CountryCode']
      end

      def document_number
        id_auth_field_data['Fields_DocumentNumber']
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

      def sex
        parse_sex_value(authentication_result_field_data&.[]('Sex'))
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

      def generate_state_id_pii
        Pii::StateId.new(
          first_name:,
          last_name:,
          middle_name:,
          name_suffix: id_auth_field_data['Fields_NameSuffix'],
          address1: id_auth_field_data['Fields_AddressLine1'],
          address2: id_auth_field_data['Fields_AddressLine2'],
          city: id_auth_field_data['Fields_City'],
          state: id_auth_field_data['Fields_State'],
          zipcode: id_auth_field_data['Fields_PostalCode'],
          dob:,
          sex:,
          height: parse_height_value(id_auth_field_data['Fields_Height']),
          weight: nil,
          eye_color: nil,
          state_id_expiration: expiration_date,
          state_id_issued: issue_date,
          state_id_jurisdiction: id_auth_field_data['Fields_IssuingStateCode'],
          state_id_number: document_number,
          state_id_type:,
          issuing_country_code:,
        )
      end

      def generate_passport_pii
        Pii::Passport.new(
          first_name:,
          last_name:,
          middle_name:,
          dob:,
          sex:,
          passport_expiration: expiration_date,
          passport_issued: issue_date,
          state_id_type:,
          issuing_country_code:,
          document_number:,
          birth_place: id_auth_field_data['Fields_BirthPlace'],
          nationality_code: id_auth_field_data['Fields_NationalityCode'],
          mrz: id_auth_field_data['Fields_MRZ'],
        )
      end
    end
  end
end
