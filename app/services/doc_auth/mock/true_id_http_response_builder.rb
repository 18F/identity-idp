require 'faker'

module DocAuth
  module Mock
    class TrueIdHttpResponseBuilder
      include YmlLoaderConcern
      def initialize(templatefile: nil)
        @template_file = templatefile
        @template = read_fixture_file_at_path(templatefile)
        parse_template
      end

      def use_uploaded_file(upload_file_content)
        @uploaded_file = upload_file_content
      end

      def alerts
        process_alerts
      end

      def alert_idx(alert_name)
        details = param_details
        detail = details.select do |d|
          d[:Group] == 'AUTHENTICATION_RESULT' && d[:Values][0][:Value] == alert_name
        end
        return 0 if detail.empty?
        alert_index_name = detail[0][:Name]
        name_spec = alert_index_name.split('_')
        return 0 if name_spec.size < 3
        name_spec[1]
      end

      def set_alert_result(alert_name, result)
        idx = alert_idx(alert_name)
        details = param_details
        detail = details.select do |d|
          d[:Group] == 'AUTHENTICATION_RESULT' && d[:Name] == "Alert_#{idx}_AuthenticationResult"
        end
        detail[0][:Values][0][:Value] = result
      end

      def set_doc_auth_result(result)
        details = param_details
        detail = details.select do |d|
          d[:Group] == 'AUTHENTICATION_RESULT' && d[:Name] == 'DocAuthResult'
        end
        detail[0][:Values][0][:Value] = result
      end

      def set_doc_auth_info(
        doc_name:,
        doc_issuer_code:,
        doc_issue:,
        doc_class_code: 'DriversLicense',
        doc_class: 'DriversLicense',
        doc_class_name: 'Drivers License',
        doc_issue_type: "Driver's License - STAR",
        doc_issuer_type: 'StateProvince',
        doc_size: 'ID1'
      )
        details = param_details
        target_details = details.select { |d| d[:Group] == 'AUTHENTICATION_RESULT' }
        target_details.each do |d|
          case d[:Name]
          when 'DocumentName'
            set_value(detail: d, value: doc_name)
          when 'DocIssuerCode'
            d[:Values][0][:Value] = doc_issuer_code
          when 'DocClassCode'
            d[:Values][0][:Value] = doc_class_code
          when 'DocClassName'
            d[:Values][0][:Value] = doc_class_name
          when 'DocClass'
            d[:Values][0][:Value] = doc_class
          when 'DocIssuerType'
            d[:Values][0][:Value] = doc_issuer_type
          when 'DocIssue'
            d[:Values][0][:Value] = doc_issue
          when 'DocIssueType'
            d[:Values][0][:Value] = doc_issue_type
          when 'DocSize'
            d[:Values][0][:Value] = doc_size unless doc_size.blank?
          end
        end
      end

      def set_portrait_match_result(result:, status_code:, error_msg:)
        details = param_details
        target_details = details.select { |d| d[:Group] == 'PORTRAIT_MATCH_RESULT' }
        target_details.each do |target_detail|
          case target_detail[:Name]
          when 'FaceStatusCode'
            target_detail[:Values][0][:Value] = status_code
          when 'FaceMatchResult'
            target_detail[:Values][0][:Value] = result
          when 'FaceErrorMessage'
            target_detail[:Values][0][:Value] = error_msg
          end
        end
      end

      def no_portrait_match_result
        all_details = param_details
        all_details.delete_if { |d| d[:Group] == 'PORTRAIT_MATCH_RESULT' }
      end

      def set_name(first_name:, last_name:, middle_name:)
        grp_name = 'IDAUTH_FIELD_DATA'
        details = param_details
        target_details = details.select { |d| d[:Group] == grp_name }
        target_details.each do |d|
          case d[:Name]
          when 'Fields_Surname'
            d[:Values][0][:Value] = last_name
          when 'Fields_FirstName'
            d[:Values][0][:Value] = first_name
          when 'Fields_MiddleName'
            d[:Values][0][:Value] = middle_name.nil? ? '' : middle_name.strip!
          when 'Fields_GivenName'
            d[:Values][0][:Value] = "#{first_name} #{middle_name}".strip!
          when 'Fields_FullName'
            if middle_name.blank?
              d[:Values][0][:Value] = "#{first_name} #{last_name}"
            else
              d[:Values][0][:Value] = "#{first_name} #{middle_name} #{last_name}"
            end
          end
        end
      end

      def set_dob(year:, month:, day:, sex:)
        grp_name = 'IDAUTH_FIELD_DATA'
        details = param_details
        target_details = details.select { |d| d[:Group] == grp_name }
        target_details.each do |d|
          case d[:Name]
          when 'Fields_DOB_Year'
            d[:Values][0][:Value] = year
          when 'Fields_DOBMonth'
            d[:Values][0][:Value] = month
          when 'Fields_DOBDay'
            d[:Values][0][:Value] = day
          when 'Fields_Sex'
            sex_s = sex == 'Male' || sex == 'M' ? 'M' : 'F'
            d[:Values][0][:Value] = sex_s
          end
        end
      end

      def set_document(
        document_number:, expiration_year:, expiration_month:, expiration_day:,
        issuing_st_code:, issuing_st_name:, issuing_year:, issuing_month:,
        issuing_day:, document_class_name: 'Drivers License'
      )
        grp_name = 'IDAUTH_FIELD_DATA'
        details = param_details
        target_details = details.select { |d| d[:Group] == grp_name }
        target_details.each do |d|
          case d[:Name]
          when 'Fields_DocumentClassName'
            d[:Values][0][:Value] = document_class_name
          when 'Fields_DocumentNumber'
            d[:Values][0][:Value] = document_number
          when 'Fields_ExpirationDate_Month'
            d[:Values][0][:Value] = expiration_month
          when 'Fields_xpirationDate_Day'
            d[:Values][0][:Value] = expiration_day
          when 'Fields_ExpirationDate_Year'
            d[:Values][0][:Value] = expiration_year
          when 'Fields_IssuingStateCode'
            d[:Values][0][:Value] = issuing_st_code
          when 'Fields_IssuingStateName'
            d[:Values][0][:Value] = issuing_st_name
          when 'Fields_IssueDate_Year'
            d[:Values][0][:Value] = issuing_year
          when 'Fields_IssueDate_Month'
            d[:Values][0][:Value] = issuing_month
          when 'Fields_IssueDate_Day'
            d[:Values][0][:Value] = issuing_day
          end
        end
      end

      def set_address(address_line1:, city:, state:, postal_code:, address_line2: nil)
        grp_name = 'IDAUTH_FIELD_DATA'
        details = param_details
        target_details = details.select { |d| d[:Group] == grp_name }
        address_line2_set = false
        target_details.each do |d|
          case d[:Name]
          when 'Fields_AddressLine1'
            d[:Values][0][:Value] = address_line1
          when 'Fields_AddressLine2'
            if !address_line2.blank?
              d[:Values][0][:Value] = address_line2
              address_line2_set
            else
              d[:Values][0][:Value] = ''
            end
          when 'Fields_Address'
            address = "#{address_line1}xE2x80xA8#{city}, #{state}, #{postal_code}"
            d[:Values][0][:Value] = address
          when 'Fields_State'
            d[:Values][0][:Value] = state
          when 'Fields_City'
            d[:Values][0][:Value] = city
          when 'Fields_PostalCode'
            d[:Values][0][:Value] = postal_code
          end
        end
        if !address_line2_set && !address_line2.blank?
          line2_detail = {
            Group: 'IDAUTH_FIELD_DATA',
            Name: 'Fields_AddressLine2',
            Values: [
              { Value: address_line2 },
            ],
          }
          target_details.append(line2_detail)
        end
      end

      def set_image_metrics(
        front_data, back_data
      )
        grp_name = 'IMAGE_METRICS_RESULT'
        details = param_details
        target_details = details.select { |d| d[:Group] == grp_name }
        front = front_data&.symbolize_keys
        back = back_data&.symbolize_keys
        target_details.each do |d|
          name = d[:Name]
          case name
          when 'GlareMetric'
            v = front&.dig(:GlareMetric)
            d[:Values][0][:Value] = v unless v.blank?
            w = back&.dig(:GlareMetric)
            d[:Values][1][:Value] = w unless w.blank?
          when 'SharpnessMetric'
            v = front&.dig(:SharpnessMetric)
            d[:Values][0][:Value] = v unless v.blank?
            w = back&.dig(:SharpnessMetric)
            d[:Values][1][:Value] = w unless w.blank?
          when 'HorizontalResolution'
            v = front&.dig(:HorizontalResolution)
            d[:Values][0][:Value] = v unless v.blank?
            w = back&.dig(:HorizontalResolution)
            d[:Values][1][:Value] = w unless w.blank?
          when 'VerticalResolution'
            v = front&.dig(:VerticalResolution)
            d[:Values][0][:Value] = v unless v.blank?
            w = back&.dig(:VerticalResolution)
            d[:Values][1][:Value] = w unless w.blank?
          when 'IsTampered'
            v = front&.dig(:Tampered, false)
            d[:Values][0][:Value] = 1 unless !!v
            w = back&.dig(:Tampered)
            d[:Values][1][:Value] = 1 unless !!w
          end
        end
      end

      def set_transaction_status(
        status = 'passed',
        code = 'trueid_pass'
      )
        status_data = @parsed_template[:Status]
        status_data[:TransactionStatus] = status
        status_data[:TransactionReasonCode][:Code] = code
      end

      def set_product_status(status = 'pass')
        return if status.blank?
        products = @parsed_template.dig(:Products)
        product = products.select do |p|
          p.key?(:ProductType) && p[:ProductType] == 'TrueID'
        end
        product[0][:ProductStatus] = status
      end

      def set_decision_status(status: 'pass')
        return if status.blank?
        products = @parsed_template.dig(:Products)
        product = products.select do |p|
          p.key?(:ProductType) && p[:ProductType] == 'TrueID_Decision'
        end
        product[0][:ProductStatus] = status
      end

      def with_default_pii
        # Faker::Config.random = Random.new(42)
        last_name = Faker::Name.last_name
        first_name = Faker::Name.first_name
        middle_name = Faker::Name.middle_name
        set_name(first_name: first_name, middle_name: middle_name, last_name: last_name)

        # dob
        dob = DateTime.now - 22.years
        set_dob(
          year: dob.year, month: dob.month, day: dob.day,
          sex: [true, false].sample ? 'M' : 'F'
        )

        # doc class info
        # a
        issue_st_code = Faker::Address.state_abbr
        issue_st_name = state_name(issue_st_code.to_sym)
        issue_date = Faker::Date.between(from: 3.years.ago, to: Time.zone.today - 10.days)
        exp_date = issue_date + 5.years
        document_num = Faker::DrivingLicence.usa_driving_licence(issue_st_name)
        set_document(
          document_number: document_num,
          issuing_st_code: issue_st_code,
          issuing_st_name: issue_st_name,
          issuing_year: issue_date.year,
          issuing_month: issue_date.month,
          issuing_day: issue_date.day,
          expiration_year: exp_date.year,
          expiration_month: exp_date.month,
          expiration_day: exp_date.day,
        )

        set_doc_auth_info(
          doc_name: "#{issue_st_name} Driver's License - STAR",
          doc_issuer_code: issue_st_code,
          doc_issue: issue_st_name,
        )
        # address
        set_address(
          address_line1: Faker::Address.street_address,
          city: Faker::Address.city,
          state: issue_st_code,
          postal_code: Faker::Address.zip(state_abbreviation: issue_st_code),
        )
      end

      def build
        @parsed_template.to_json
      end

      private

      def param_details
        products = @parsed_template.dig(:Products)
        product = products.select do |p|
          p.key?(:ParameterDetails) && p[:ParameterDetails].is_a?(Array)
        end
        product[0].dig(:ParameterDetails)
      end

      def process_alerts
        return if parsed_alerts.blank?
        parsed_alerts.to_h do |parsed_alert|
          [parsed_alert.dig('name'), parsed_alert.dig('result')]
        end
      end

      def read_fixture_file_at_path(filepath)
        expanded_path = Rails.root.join(
          'spec',
          'fixtures',
          'proofing',
          'lexis_nexis',
          'true_id',
          filepath,
        )
        File.read(expanded_path)
      end

      def parse_template
        @parsed_template = JSON.parse(@template, symbolize_names: true)
      end

      def parsed_data_from_uploaded_file
        return @parsed_data_from_uploaded_file if defined?(@parsed_data_from_uploaded_file)

        @parsed_data_from_uploaded_file = parse_yaml(@uploaded_file)
      end

      def parsed_alerts
        parsed_data_from_uploaded_file&.dig('failed_alerts')
      end

      def set_value(detail:, value:, default_value: '')
        if value.blank? && !default_value.blank?
          detail[:Values][0][:Value] = default_value
        else
          detail[:Values][0][:Value] = value unless value.blank?
        end
      end

      def state_name(state_abbr)
        states = { AK: 'Alaska',
                   AL: 'Alabama',
                   AS: 'American Samoa',
                   AZ: 'Arizona',
                   AR: 'Arkansas',
                   CA: 'California',
                   CO: 'Colorado',
                   CT: 'Connecticut',
                   DE: 'Delaware',
                   DC: 'District of Columbia',
                   FM: 'Federated States of Micronesia',
                   FL: 'Florida',
                   GA: 'Georgia',
                   GU: 'Guam',
                   HI: 'Hawaii',
                   ID: 'Idaho',
                   IL: 'Illinois',
                   IN: 'Indiana',
                   IA: 'Iowa',
                   KS: 'Kansas',
                   KY: 'Kentucky',
                   LA: 'Louisiana',
                   ME: 'Maine',
                   MH: 'Marshall Islands',
                   MD: 'Maryland',
                   MA: 'Massachusetts',
                   MI: 'Michigan',
                   MN: 'Minnesota',
                   MS: 'Mississippi',
                   MO: 'Missouri',
                   MT: 'Montana',
                   NE: 'Nebraska',
                   NV: 'Nevada',
                   NH: 'New Hampshire',
                   NJ: 'New Jersey',
                   NM: 'New Mexico',
                   NY: 'New York',
                   NC: 'North Carolina',
                   ND: 'North Dakota',
                   MP: 'Northern Mariana Islands',
                   OH: 'Ohio',
                   OK: 'Oklahoma',
                   OR: 'Oregon',
                   PW: 'Palau',
                   PA: 'Pennsylvania',
                   PR: 'Puerto Rico',
                   RI: 'Rhode Island',
                   SC: 'South Carolina',
                   SD: 'South Dakota',
                   TN: 'Tennessee',
                   TX: 'Texas',
                   UT: 'Utah',
                   VT: 'Vermont',
                   VI: 'Virgin Islands',
                   VA: 'Virginia',
                   WA: 'Washington',
                   WV: 'West Virginia',
                   WI: 'Wisconsin',
                   WY: 'Wyoming',
                   AE: 'Armed Forces Middle East',
                   AA: 'Armed Forces Americas (except Canada)',
                   AP: 'Armed Forces Pacific' }
        states[state_abbr] || state_abbr.to_s
      end
    end
  end
end
