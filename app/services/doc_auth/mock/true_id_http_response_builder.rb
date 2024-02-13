require 'faker'

module DocAuth
  module Mock
    class TrueIdHttpResponseBuilder
      include YmlLoaderConcern

      def initialize(templatefile: nil, selfie_check_enabled: false)
        @template_file = templatefile
        @template = read_fixture_file_at_path(templatefile)
        @selfie_check_enabled = selfie_check_enabled
        parse_template
        available_checks
        with_mock_pii
        set_doc_auth_result(default_data[:doc_auth_result])
        set_image_metrics(default_data[:image_metrics][:front], default_data[:image_metrics][:back])
      end

      CHECK_2D_BARCODE_READ = '2D Barcode Read'

      def use_uploaded_file(upload_file_content)
        @uploaded_file = upload_file_content
        @uploaded_file_present = !upload_file_content.nil?
        @parsed_uploaded_file = parse_yaml(@uploaded_file).deep_symbolize_keys
        is_binary_file = !upload_file_content.ascii_only?
        upload_failed_alerts = @parsed_uploaded_file.dig(:failed_alerts) ||
                               @parsed_uploaded_file.dig(:failed_alert)
        pii = @parsed_uploaded_file[:document] || {}
        pii_available = !pii.blank?
        if pii_available
          set_doc_auth_result('Passed')
          set_check_status(CHECK_2D_BARCODE_READ, 'Passed')
        elsif upload_failed_alerts.nil?
          set_check_status(CHECK_2D_BARCODE_READ, 'Failed')
          set_doc_auth_result('Failed')
        elsif upload_failed_alerts.empty?
          set_doc_auth_result('Passed')
          set_check_status(CHECK_2D_BARCODE_READ, 'Passed')
        else
          set_doc_auth_result('Failed')
          set_check_status(CHECK_2D_BARCODE_READ, 'Passed')
        end
        update_with_yaml(@parsed_uploaded_file)
        if @uploaded_file_present
          set_pii(pii)
          # when using image, we do not remove data
          clean_up_pii(pii) unless is_binary_file
        end
      end

      def alert_idx(alert_name)
        available_checks.dig(alert_name)
      end

      def set_doc_auth_result(result)
        details = param_details
        detail = details.select do |d|
          d[:Group] == 'AUTHENTICATION_RESULT' && d[:Name] == 'DocAuthResult'
        end
        detail[0][:Values][0][:Value] = (result.presence || 'Passed')
      end

      def set_doc_auth_info(
        doc_name: nil,
        doc_issuer_code: nil,
        doc_issue: nil,
        doc_class_code: 'DriversLicense',
        doc_class: 'DriversLicense',
        doc_class_name: 'Drivers License',
        doc_issue_type: "Driver's License - STAR",
        doc_issuer_type: 'StateProvince',
        doc_size: 'ID1',
        expire_date: nil,
        doc_issuer_name: nil
      )
        details = param_details
        target_details = details.select { |d| d[:Group] == 'AUTHENTICATION_RESULT' }
        # rubocop:disable Metrics/BlockLength
        target_details.each do |d|
          case d[:Name]
          when 'DocumentName'
            set_value(detail: d, value: doc_name)
          when 'DocIssuerCode'
            set_value(detail: d, value: doc_issuer_code)
          when 'DocClassCode'
            set_value(detail: d, value: doc_class_code)
          when 'DocClassName'
            set_value(detail: d, value: doc_class_name)
          when 'DocClass'
            set_value(detail: d, value: doc_class)
          when 'DocIssuerType'
            set_value(detail: d, value: doc_issuer_type)
          when 'DocIssuerName'
            set_value(detail: d, value: doc_issuer_name)
          when 'DocIssue'
            set_value(detail: d, value: doc_issue)
          when 'DocIssueType'
            set_value(detail: d, value: doc_issue_type)
          when 'DocSize'
            set_value(detail: d, value: doc_size)
          when 'ExpirationDate_Year'
            set_value(detail: d, value: expire_date.year.to_s) unless expire_date.blank?
          when 'ExpirationDate_Month'
            set_value(detail: d, value: expire_date.month.to_s) unless expire_date.blank?
          when 'ExpirationDate_Day'
            set_value(detail: d, value: expire_date.day.to_s) unless expire_date.blank?
          end
          # rubocop:enable Metrics/BlockLength
        end
      end

      def set_portrait_match_result(result:, error_msg:, status_code: nil)
        details = param_details
        target_details = details.select { |d| d[:Group] == 'PORTRAIT_MATCH_RESULT' }
        target_details.each do |target_detail|
          case target_detail[:Name]
          when 'FaceStatusCode'
            set_value(detail: target_detail, value: status_code)
          when 'FaceMatchResult'
            set_value(detail: target_detail, value: result)
          when 'FaceErrorMessage'
            set_value(detail: target_detail, value: error_msg)
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
            set_value(detail: d, value: year&.to_s)
          when 'Fields_DOB_Month'
            set_value(detail: d, value: month&.to_s)
          when 'Fields_DOB_Day'
            set_value(detail: d, value: day&.to_s)
          when 'Fields_Sex'
            sex_s = sex == 'Male' || sex == 'M' ? 'M' : 'F'
            set_value(detail: d, value: sex_s)
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
        # rubocop:disable Metrics/BlockLength
        target_details.each do |d|
          case d[:Name]
          when 'Fields_DocumentClassName'
            v = document_class_name
            set_value(detail: d, value: v)
          when 'Fields_DocumentNumber'
            v = document_number
            set_value(detail: d, value: v)
          when 'Fields_ExpirationDate_Month'
            v = expiration_month&.to_s
            set_value(detail: d, value: v)
          when 'Fields_xpirationDate_Day'
            v = expiration_day&.to_s
            set_value(detail: d, value: v)
          when 'Fields_ExpirationDate_Year'
            v = expiration_year&.to_s
            set_value(detail: d, value: v)
          when 'Fields_IssuingStateCode'
            v = issuing_st_code
            set_value(detail: d, value: v)
          when 'Fields_IssuingStateName'
            v = issuing_st_name
            set_value(detail: d, value: v)
          when 'Fields_IssueDate_Year'
            set_value(detail: d, value: issuing_year&.to_s)
          when 'Fields_IssueDate_Month'
            set_value(detail: d, value: issuing_month&.to_s)
          when 'Fields_IssueDate_Day'
            set_value(detail: d, value: issuing_day&.to_s)
          end
        end
        # rubocop:enable Metrics/BlockLength
      end

      def set_issuing_country_code(
        country_code = 'USA'
      )
        grp_name = 'IDAUTH_FIELD_DATA'
        details = param_details
        target_details = details.select do |d|
          d[:Group] == grp_name && d[:Name] == 'Fields_CountryCode'
        end
        target_details[0][:Values][0][:Value] = country_code
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

      def set_pii(
        pii_info
      )
        return if pii_info.blank?
        supported_keys = PII_MAPPING.values
        dob = pii_info[:dob]
        unless dob.blank?
          dob_date = Date.strptime(dob)
          pii_info[:dob_year] = dob_date.year
          pii_info[:dob_month] = dob_date.month
          pii_info[:dob_day] = dob_date.day
        end

        expiration = pii_info[:state_id_expiration]
        unless expiration.blank?
          Rails.logger.debug { "expiration: #{expiration}" }
          exp_date = begin
            Date.parse(expiration)
          rescue
            begin
              Date.parse(expiration, '%Y-%m-%d')
            end
          end
          set_expire_date(exp_date)
          if exp_date.past?
            set_id_auth_field('Document Expired', 'Failed')
          end
        end

        issued = pii_info[:state_id_issued]
        unless issued.blank?
          issued_date = begin
            Date.strptime(issued, '%m/%d/%Y')
          rescue
            Date.strptime(issued, '%Y-%m-%d')
          end
          pii_info[:state_id_issued_year] = issued_date.year
          pii_info[:state_id_issued_month] = issued_date.month
          pii_info[:state_id_issued_day] = issued_date.day
        end
        id_state = pii_info[:state_id_jurisdiction]
        unless id_state.blank?
          field_name = 'Fields_IssuingStateName'
          state = state_name(id_state)
          set_id_auth_field(field_name, state)
          set_doc_auth_info(
            doc_issuer_code: id_state,
            doc_issuer_name: state,
          )
        end
        pii_info.slice(*supported_keys)
        return if pii_info.blank?
        id_type = pii_info.delete(:state_id_type)
        unless id_type.blank?
          value = id_type.humanize.titleize
          set_id_auth_field(pii_field_name(:state_id_type), value)
          set_doc_auth_info(
            doc_class_name: value,
            doc_class: value.split(' ').join(''),
            doc_class_code: value.split(' ').join(''),
            doc_name: "#{state_name(id_state)} #{value}",
          )
        end
        pii_info.each do |key, value|
          filed_name = pii_field_name(key)
          set_id_auth_field(filed_name, value)
        end
      end

      def set_image_metrics(
        front_data, back_data
      )
        return if front_data.blank? && back_data.blank?
        grp_name = 'IMAGE_METRICS_RESULT'
        details = param_details
        target_details = details.select { |d| d[:Group] == grp_name }
        front = front_data&.symbolize_keys
        back = back_data&.symbolize_keys
        # rubocop:disable Metrics/BlockLength
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
        # rubocop:enable Metrics/BlockLength
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

      def set_expire_date(expire_date)
        return if expire_date.blank?
        grp_name = 'IDAUTH_FIELD_DATA'
        details = param_details
        target_details = details.select { |d| d[:Group] == grp_name }
        target_details.each do |d|
          case d[:Name]
          when 'Fields_ExpirationDate_Month'
            v = expire_date.month.to_s
            set_value(detail: d, value: v)
          when 'Fields_xpirationDate_Day'
            v = expire_date.day.to_s
            set_value(detail: d, value: v)
          when 'Fields_ExpirationDate_Year'
            v = expire_date.year.to_s
            set_value(detail: d, value: v)
          end
        end
        target_details = details.select { |d| d[:Group] == 'AUTHENTICATION_RESULT' }
        target_details.each do |d|
          case d[:Name]
          when 'ExpirationDate_Year'
            set_value(detail: d, value: expire_date.year.to_s)
          when 'ExpirationDate_Month'
            set_value(detail: d, value: expire_date.month.to_s)
          when 'ExpirationDate_Day'
            set_value(detail: d, value: expire_date.day.to_s)
          end
        end
        if expire_date.past?
          set_check_status('Document Expired', 'Failed')
        end
      end

      def set_check_status(check_name, status)
        idx = available_checks[check_name]
        grp_name = 'AUTHENTICATION_RESULT'
        details = param_details
        alert_name = "Alert_#{idx}_AuthenticationResult"
        target_details = details.select { |d| d[:Group] == grp_name && d[:Name] == alert_name }
        return if target_details.blank?
        detail = target_details[0]
        set_value(detail: detail, value: status)
      end

      def set_id_auth_field(field_name, value)
        grp_name = 'IDAUTH_FIELD_DATA'
        details = param_details
        target_details = details.select { |d| d[:Group] == grp_name && d[:Name] == field_name }
        return if target_details.blank?
        detail = target_details[0]
        set_value(detail: detail, value: value)
      end

      def get_check_status(check_name)
        idx = available_checks[check_name]
        grp_name = 'AUTHENTICATION_RESULT'
        details = param_details
        alert_name = "Alert_#{idx}_AuthenticationResult"
        target_details = details.select { |d| d[:Group] == grp_name && d[:Name] == alert_name }
        return if target_details.blank?
        detail = target_details[0]
        detail[:Values][0][:Value]
      end

      def with_mock_pii
        last_name = Idp::Constants::MOCK_IDV_APPLICANT[:last_name]
        first_name = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
        middle_name = Idp::Constants::MOCK_IDV_APPLICANT[:middle_name]
        set_name(first_name: first_name, middle_name: middle_name, last_name: last_name)
        dob_str = Idp::Constants::MOCK_IDV_APPLICANT[:dob]
        dob = begin
          Date.parse(dob_str)
        rescue
          DateTime.no - 22.years
        end
        set_dob(
          year: dob.year, month: dob.month, day: dob.day,
          sex: [true, false].sample ? 'M' : 'F'
        )
        @issue_st_code = Idp::Constants::MOCK_IDV_APPLICANT[:state] || Faker::Address.state_abbr
        @issue_st_name = state_name(@issue_st_code.to_sym)
        @issue_date = begin
          Date.parse(Idp::Constants::MOCK_IDV_APPLICANT[:state_id_issued])
        rescue
          Faker::Date.between(
            from: 3.years.ago.to_s,
            to: (Time.zone.today - 10.days).to_s,
          )
        end
        @exp_date = begin
          Date.parse(Idp::Constants::MOCK_IDV_APPLICANT[:state_id_expiration])
        rescue
          @issue_date + 5.years
        end
        document_num = Idp::Constants::MOCK_IDV_APPLICANT[:state_id_number] ||
                       Faker::DrivingLicence.usa_driving_licence(@issue_st_name)
        set_document(
          document_number: document_num,
          issuing_st_code: @issue_st_code,
          issuing_st_name: @issue_st_name,
          issuing_year: @issue_date.year,
          issuing_month: @issue_date.month,
          issuing_day: @issue_date.day,
          expiration_year: @exp_date.year,
          expiration_month: @exp_date.month,
          expiration_day: @exp_date.day,
        )
        set_doc_auth_info(
          doc_name: "#{@issue_st_name} Driver's License - STAR",
          doc_issuer_code: @issue_st_code,
          doc_issue: @issue_st_name,
          expire_date: @exp_date,
        )
        # address
        # rubocop:disable Layout/LineLength
        set_address(
          address_line1: Idp::Constants::MOCK_IDV_APPLICANT[:address1] || Faker::Address.street_address,
          city: Idp::Constants::MOCK_IDV_APPLICANT[:city] || Faker::Address.city,
          state: Idp::Constants::MOCK_IDV_APPLICANT[:state] || @issue_st_code,
          postal_code: Idp::Constants::MOCK_IDV_APPLICANT[:zipcode] || Faker::Address.zip(state_abbreviation: @issue_st_code),
        )
        # rubocop:enable Layout/LineLength
      end

      def with_random_pii
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

        @issue_st_code = Faker::Address.state_abbr
        @issue_st_name = state_name(@issue_st_code.to_sym)
        @issue_date = Faker::Date.between(
          from: 3.years.ago.to_s,
          to: (Time.zone.today - 10.days).to_s,
        )
        @exp_date = @issue_date + 5.years

        document_num = Faker::DrivingLicence.usa_driving_licence(@issue_st_name)
        set_document(
          document_number: document_num,
          issuing_st_code: @issue_st_code,
          issuing_st_name: @issue_st_name,
          issuing_year: @issue_date.year,
          issuing_month: @issue_date.month,
          issuing_day: @issue_date.day,
          expiration_year: @exp_date.year,
          expiration_month: @exp_date.month,
          expiration_day: @exp_date.day,
        )

        set_doc_auth_info(
          doc_name: "#{@issue_st_name} Driver's License - STAR",
          doc_issuer_code: @issue_st_code,
          doc_issue: @issue_st_name,
          expire_date: @exp_date,
        )
        # address
        set_address(
          address_line1: Faker::Address.street_address,
          city: Faker::Address.city,
          state: @issue_st_code,
          postal_code: Faker::Address.zip(state_abbreviation: @issue_st_code),
        )
      end

      def build
        clean_unknown_alert
        @parsed_template.to_json
      end

      def available_checks
        return @available_checks if defined?(@available_checks)
        @available_checks = [] if @template.blank?
        template_data = JSON.parse(@template, symbolize_names: true)
        products = template_data.dig(:Products)
        product = products.select do |p|
          p.key?(:ParameterDetails) && p[:ParameterDetails].is_a?(Array)
        end
        details = product[0].dig(:ParameterDetails)
        checks = {}
        details.each do |d|
          next unless d[:Group] == 'AUTHENTICATION_RESULT' && d[:Name].end_with?('_AlertName')
          check_name = d[:Values][0][:Value]
          check_index = d[:Name].split('_')[1]
          checks[check_name] = check_index
        end
        @available_checks = checks
      end

      def clean_unknown_alert
        unknown_alert = ['Series Expired', 'Document Tampering Detection', 'Barcode Encoding']
        details = param_details
        target_details = details.select do |d|
          d[:Group] == 'AUTHENTICATION_RESULT' && unknown_alert.include?(d[:Values][0][:Value])
        end
        idx = []
        target_details.each do |d|
          idx << d[:Name].split('_')[1]
        end
        details.delete_if do |d|
          d[:Group] == 'AUTHENTICATION_RESULT' && idx.include?(d[:Name].split('_')[1])
        end
      end

      private

      def update_with_yaml(parsed_uploaded_file)
        return if parsed_uploaded_file.blank?
        file_data = parsed_uploaded_file
        doc_auth_result = file_data.dig(:doc_auth_result)
        set_doc_auth_result(doc_auth_result) unless doc_auth_result.blank?
        image_metrics = file_data.dig(:image_metrics)
        unless image_metrics.blank?
          set_image_metrics(image_metrics[:front], image_metrics[:back])
        end
        failed_alerts = file_data.dig(:failed_alerts)
        unless failed_alerts.blank?
          failed_alerts.each do |alert|
            name = alert[:name]
            value = alert[:result]
            set_check_status(name, value)
          end
        end

        if @selfie_check_enabled
          portrait_match_result = file_data.dig(:portrait_match_results)
          unless portrait_match_result.blank?
            set_portrait_match_result(
              result: portrait_match_result[:FaceMatchResult],
              error_msg: portrait_match_result[:FaceErrorMessage],
            )
          end
        else
          # remove portrait match part
          no_portrait_match_result
        end

        classification_info = file_data.dig(:classification_info, :Front)
        doc_class = classification_info&.dig(:ClassName)
        issuer_type = classification_info&.dig(:IssuerType)
        country_code = classification_info&.dig(:CountryCode)

        set_doc_auth_info(
          doc_name: "#{@issue_st_name} #{doc_class}",
          doc_class_name: doc_class,
          doc_class: doc_class&.split('_')&.join(''),
          doc_class_code: doc_class&.split('_')&.join(''),
          doc_issuer_type: issuer_type,
          doc_issuer_code: @issue_st_name,
          doc_issue: @issue_date.year.to_s,
        )
        set_issuing_country_code(country_code) unless country_code.blank?
      end

      def param_details
        products = @parsed_template.dig(:Products)
        product = products.select do |p|
          p.key?(:ParameterDetails) && p[:ParameterDetails].is_a?(Array)
        end
        product[0].dig(:ParameterDetails)
      end

      def process_alerts_input
        return if parsed_input_alerts.blank?
        parsed_input_alerts.to_h do |parsed_alert|
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
        states[state_abbr.to_sym] || state_abbr.to_s
      end

      def pii_field_name(pii_key)
        PII_MAPPING.key(pii_key)
      end

      def default_data
        {
          doc_auth_result: 'Passed',
          image_metrics: {
            front: {
              'VerticalResolution' => 600,
              'HorizontalResolution' => 600,
              'GlareMetric' => 100,
              'SharpnessMetric' => 100,
            },
            back: {
              'VerticalResolution' => 600,
              'HorizontalResolution' => 600,
              'GlareMetric' => 100,
              'SharpnessMetric' => 100,
            },
          },
        }.deep_symbolize_keys
      end

      public def parse_yaml(uploaded_file)
        data = default_data.clone
        data[:failed_alerts] = []
        serialized_data = uploaded_file.ascii_only? ?
                            uploaded_file : data.deep_stringify_keys.to_yaml
        super(serialized_data)
      end

      def clean_up_pii(pii)
        # pii non empty
        return if pii.nil?
        missing_keys = %i[first_name last_name address1 address2 dob city state zipcode
                          state_id_number state_id_type state_id_expiration state_id_issued
                          state_id_jurisdiction issuing_country_code middle_name] - pii.keys
        id_auth_fields_missing = []
        missing_keys.each do |missing_key|
          case missing_key
          when :dob
            id_auth_fields_missing << pii_field_name(:dob_year)
            id_auth_fields_missing << pii_field_name(:dob_month)
            id_auth_fields_missing << pii_field_name(:dob_day)
          when :state_id_expiration
            id_auth_fields_missing << pii_field_name(:state_id_expiration_year)
            id_auth_fields_missing << pii_field_name(:state_id_expiration_month)
            id_auth_fields_missing << pii_field_name(:state_id_expiration_day)
          when :state_id_issued
            id_auth_fields_missing << pii_field_name(:state_id_issued_year)
            id_auth_fields_missing << pii_field_name(:state_id_issued_month)
            id_auth_fields_missing << pii_field_name(:state_id_issued_day)
          else
            field_name = pii_field_name(missing_key)
            id_auth_fields_missing << field_name if field_name.present?
          end
        end
        remove_id_auth_fields(id_auth_fields_missing)
      end

      def remove_id_auth_fields(fields)
        return if fields.blank?
        details = param_details
        details.delete_if do |d|
          d[:Group] == 'IDAUTH_FIELD_DATA' && fields.include?(d[:Name])
        end
      end

      PII_MAPPING = {
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
    end
  end
end
