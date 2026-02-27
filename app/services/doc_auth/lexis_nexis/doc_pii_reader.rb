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
      def read_pii
        return nil unless true_id_product&.dig(:IDAUTH_FIELD_DATA).present?

        if Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES.include?(document_type_received)
          generate_state_id_pii
        elsif Idp::Constants::DocumentTypes::PASSPORT_TYPES.include?(document_type_received)
          generate_passport_pii
        end
      end

      def document_type_received
        @document_type_received ||= determine_document_type_received(
          doc_class_name: doc_class_name,
          doc_issue_type: doc_issue_type,
        )
      end

      def generate_state_id_pii
        Pii::StateId.new(
          first_name:,
          last_name:,
          middle_name:,
          name_suffix: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_NameSuffix),
          address1: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_AddressLine1),
          address2: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_AddressLine2),
          city: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_City),
          state: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_State),
          zipcode:,
          dob:,
          sex:,
          height: parse_height_value(true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_Height)),
          weight: nil,
          eye_color: nil,
          state_id_expiration: expiration_date,
          state_id_issued: issue_date,
          state_id_jurisdiction: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_IssuingStateCode),
          state_id_number: document_number,
          document_type_received:,
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
          document_type_received:,
          issuing_country_code:,
          document_number:,
          birth_place: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_BirthPlace),
          nationality_code: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_NationalityCode),
          mrz: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_MRZ),
        )
      end

      # PII fields #########################################################################

      def first_name
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_FirstName) ||
          true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_GivenName)
      end

      def middle_name
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_MiddleName)
      end

      def last_name
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_Surname)
      end

      def name_suffix
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_NameSuffix)
      end

      def dob
        parse_date(
          year: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_DOB_Year),
          month: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_DOB_Month),
          day: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_DOB_Day),
        )
      end

      def document_number
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_DocumentNumber)
      end

      def expiration_date
        parse_date(
          year: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_ExpirationDate_Year),
          month: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_ExpirationDate_Month),
          day: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_xpirationDate_Day),
          #                                                     ^^^ this is NOT a typo
        )
      end

      def issue_date
        parse_date(
          year: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_IssueDate_Year),
          month: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_IssueDate_Month),
          day: true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_IssueDate_Day),
        )
      end

      def issuing_country_code
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_CountryCode)
      end

      def address1
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_AddressLine1)
      end

      def address2
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_AddressLine2)
      end

      def city
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_City)
      end

      def state
        true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_State)
      end

      def zipcode
        zip = true_id_product&.dig(:IDAUTH_FIELD_DATA, :Fields_PostalCode)
        unless /^\d{5}(-\d{4})?$/.match? zip
          zip = zip&.slice(0, 5)
        end
        zip
      end

      def sex
        parse_sex_value(true_id_product&.dig(:AUTHENTICATION_RESULT, :Sex))
      end

      # Utility methods ####################################################################

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

      def determine_document_type_received(doc_class_name:, doc_issue_type:)
        val = DocumentClassifications::CLASSIFICATION_TO_DOCUMENT_TYPE[doc_class_name]

        # If the DocIssueType is 'Passport Card',
        # LN is returning 'Identification Card' as the DocClassName so we need to differentiate
        # between a passport card and a state-issued identification card.
        if doc_issue_type == 'Passport Card'
          val = 'passport_card'
        end
        val
      end
    end
  end
end
