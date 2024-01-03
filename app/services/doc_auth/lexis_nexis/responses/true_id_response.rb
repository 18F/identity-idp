# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      class TrueIdResponse < DocAuth::Response
        include ClassificationConcern
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
        attr_reader :config, :http_response

        def initialize(http_response, config, liveness_checking_enabled = false)
          @config = config
          @http_response = http_response
          @liveness_checking_enabled = liveness_checking_enabled
          super(
            success: successful_result?,
            errors: error_messages,
            extra: extra_attributes,
            pii_from_doc: pii_from_doc,
            selfie_check_performed: liveness_checking_enabled,
          )
        rescue StandardError => e
          NewRelic::Agent.notice_error(e)
          super(
            success: false,
            errors: { network: true },
            exception: e,
            extra: { backtrace: e.backtrace },
          )
        end

        def successful_result?
          (all_passed? || attention_with_barcode?) && id_type_supported?
        end

        def error_messages
          return {} if successful_result?

          if true_id_product&.dig(:AUTHENTICATION_RESULT).present?
            ErrorGenerator.new(config).generate_doc_auth_errors(response_info)
          elsif true_id_product.present?
            ErrorGenerator.wrapped_general_error(@liveness_checking_enabled)
          else
            { network: true } # return a generic technical difficulties error to user
          end
        end

        def extra_attributes
          if true_id_product&.dig(:AUTHENTICATION_RESULT).present?
            attrs = response_info.merge(true_id_product[:AUTHENTICATION_RESULT])
            attrs.reject! do |k, _v|
              PII_EXCLUDES.include?(k) || k.start_with?('Alert_')
            end
          else
            attrs = {
              lexis_nexis_status: parsed_response_body[:Status],
              lexis_nexis_info: parsed_response_body.dig(:Information),
              exception: 'LexisNexis Response Unexpected: TrueID response details not found.',
            }
          end

          basic_logging_info.merge(attrs)
        end

        def pii_from_doc
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

        def attention_with_barcode?
          return false unless doc_auth_result_attention?

          parsed_alerts[:failed]&.count.to_i == 1 &&
            parsed_alerts.dig(:failed, 0, :name) == '2D Barcode Read' &&
            parsed_alerts.dig(:failed, 0, :result) == 'Attention'
        end

        def billed?
          !!doc_auth_result
        end

        private

        def conversation_id
          @conversation_id ||= parsed_response_body.dig(:Status, :ConversationId)
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body).with_indifferent_access
        end

        def transaction_status
          parsed_response_body.dig(:Status, :TransactionStatus)
        end

        def transaction_status_passed?
          transaction_status == 'passed'
        end

        def transaction_reason_code
          @transaction_reason_code ||=
            parsed_response_body.dig(:Status, :TransactionReasonCode, :Code)
        end

        def reference
          @reference ||= parsed_response_body.dig(:Status, :Reference)
        end

        def products
          @products ||=
            parsed_response_body.dig(:Products)&.each_with_object({}) do |product, product_list|
              extract_details(product)
              product_list[product[:ProductType]] = product
            end&.with_indifferent_access
        end

        def extract_details(product)
          return unless product[:ParameterDetails]

          product[:ParameterDetails].each do |detail|
            group = detail[:Group]
            detail_name = detail[:Name]
            is_region = detail_name.end_with?('Regions', 'Regions_Reference')
            value = is_region ? detail[:Values].map { |v| v[:Value] } :
                      detail.dig(:Values, 0, :Value)
            product[group] ||= {}

            product[group][detail_name] = value
          end
        end

        def response_info
          @response_info ||= create_response_info
        end

        def create_response_info
          alerts = parsed_alerts
          log_alert_formatter = DocAuth::ProcessedAlertToLogAlertFormatter.new

          {
            transaction_status: transaction_status,
            transaction_reason_code: transaction_reason_code,
            product_status: product_status,
            decision_product_status: decision_product_status,
            doc_auth_result: doc_auth_result,
            selfie_result: selfie_result,
            processed_alerts: alerts,
            alert_failure_count: alerts[:failed]&.count.to_i,
            log_alert_results: log_alert_formatter.log_alerts(alerts),
            portrait_match_results: true_id_product[:PORTRAIT_MATCH_RESULT],
            image_metrics: parse_image_metrics,
            address_line2_present: !pii_from_doc[:address2].blank?,
            classification_info: classification_info,
          }
        end

        def basic_logging_info
          {
            conversation_id: conversation_id,
            reference: reference,
            vendor: 'TrueID',
            billed: billed?,
          }
        end

        def all_passed?
          transaction_status_passed? &&
            true_id_product.present? &&
            product_status_passed? &&
            doc_auth_result_passed? &&
            selfie_result_passed?
        end

        def product_status_passed?
          product_status == 'pass'
        end

        def doc_auth_result_passed?
          doc_auth_result == 'Passed'
        end

        def selfie_result_passed?
          # If liveness checking is disabled, don't evaluate the selfie fields in the response
          return true if !liveness_checking_enabled
          return selfie_result == 'Passed'
        end

        def doc_auth_result_attention?
          doc_auth_result == 'Attention'
        end

        def doc_class_name
          true_id_product&.dig(:AUTHENTICATION_RESULT, :DocClassName)
        end

        def doc_issuer_type
          true_id_product&.dig(:AUTHENTICATION_RESULT, :DocIssuerType)
        end

        def classification_info
          # Acuant response has both sides info, here simulate that
          doc_class = doc_class_name
          issuing_country = pii_from_doc[:issuing_country_code]
          {
            Front: {
              ClassName: doc_class,
              IssuerType: doc_issuer_type,
              CountryCode: issuing_country,
            },
            Back: {
              ClassName: doc_class,
              IssuerType: doc_issuer_type,
              CountryCode: issuing_country,
            },
          }
        end

        def doc_auth_result
          true_id_product&.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
        end

        def selfie_result
          true_id_product&.dig(:AUTHENTICATION_RESULT, :SomeFieldImNotSureOProbablyFaceMatchResult)
        end

        def product_status
          true_id_product&.dig(:ProductStatus)
        end

        def decision_product_status
          true_id_product_decision&.dig(:ProductStatus)
        end

        def true_id_product
          products[:TrueID] if products.present?
        end

        def true_id_product_decision
          products[:TrueID_Decision] if products.present?
        end

        def parsed_alerts
          return @new_alerts if defined?(@new_alerts)

          @new_alerts = { passed: [], failed: [] }
          all_alerts = true_id_product[:AUTHENTICATION_RESULT].select do |key|
            key.start_with?('Alert_')
          end

          region_details = parse_document_region
          alert_names = all_alerts.select { |key| key.end_with?('_AlertName') }
          alert_names.each do |alert_name, _v|
            alert_prefix = alert_name.scan(/Alert_\d{1,2}_/).first
            alert = combine_alert_data(all_alerts, alert_prefix, region_details)
            if alert[:result] == 'Passed'
              @new_alerts[:passed].push(alert)
            else
              @new_alerts[:failed].push(alert)
            end
          end
          @new_alerts
        end

        def combine_alert_data(all_alerts, alert_name, region_details)
          new_alert_data = {}
          # Get the set of Alerts that are all the same number (e.g. Alert_11)
          alert_set = all_alerts.select { |key| key.match?(alert_name) }

          alert_set.each do |key, value|
            new_alert_data[:alert] = alert_name.delete_suffix('_')
            new_alert_data[:name] = value if key.end_with?('_AlertName')
            new_alert_data[:result] = value if key.end_with?('_AuthenticationResult')
            new_alert_data[:region] = value if key.end_with?('_Regions')
            new_alert_data[:disposition] = value if key.end_with?('_Disposition')
            new_alert_data[:model] = value if key.end_with?('_Model')
            if key.end_with?('Regions_Reference')
              new_alert_data[:region_ref] = value.map { |v| region_details[v] }
            end
          end

          new_alert_data
        end

        def parse_image_metrics
          image_metrics = {}

          true_id_product[:ParameterDetails].each do |detail|
            next unless detail[:Group] == 'IMAGE_METRICS_RESULT'

            inner_val = detail.dig(:Values).collect { |value| value.dig(:Value) }
            image_metrics[detail[:Name]] = inner_val
          end

          transform_metrics(image_metrics)
        end

        def transform_metrics(img_metrics)
          new_metrics = {}
          img_metrics['Side']&.each_with_index do |side, i|
            new_metrics[side.downcase.to_sym] = img_metrics.transform_values { |v| v[i] }
          end

          new_metrics
        end

        # Generate a hash for image references information that can be linked to Alert
        # @return A hash with region_id => {:key : 'What region', :side: 'Front|Back'}
        def parse_document_region
          region_details = {}
          image_sides = {}
          true_id_product[:ParameterDetails].each do |detail|
            next unless detail[:Group] == 'DOCUMENT_REGION' ||
                        (detail[:Group] == 'IMAGE_METRICS_RESULT' &&
                          %w[ImageMetrics_Id Side].include?(detail[:Name]))
            inner_val = detail[:Values].map { |value| value[:Value] }
            if detail[:Group] == 'DOCUMENT_REGION'
              region_details[detail[:Name]] = inner_val
            else
              image_sides[detail[:Name]] = inner_val
            end
          end
          transform_document_region(region_details, image_sides)
        end

        def transform_document_region(region_details, image_sides)
          new_region_details = {}
          new_image_sides = {}
          image_sides['ImageMetrics_Id']&.each_with_index do |id, i|
            new_image_sides[id] = image_sides.transform_values { |v| v[i] }
          end
          region_details['DocumentRegion_Id']&.each_with_index do |region_id, i|
            new_region_details[region_id] = region_details.transform_values { |v| v[i] }
            new_region_details[region_id].delete('DocumentRegion_Id')
          end
          new_region_details.deep_transform_values! do |v|
            if new_image_sides[v]
              new_image_sides[v]['Side']
            else
              v
            end
          end
          new_region_details.deep_transform_keys! do |k|
            if k.start_with?('DocumentRegion_')
              new_key = k.sub(/DocumentRegion_/, '').downcase
              new_key = new_key == 'imagereference' ? 'side' : new_key
              new_key.to_sym
            else
              k
            end
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
      end
    end
  end
end
