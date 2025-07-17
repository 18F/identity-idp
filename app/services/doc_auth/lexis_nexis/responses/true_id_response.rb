# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      class TrueIdResponse < DocAuth::Response
        include ImageMetricsReader
        include DocPiiReader
        include ClassificationConcern
        include SelfieConcern

        attr_reader :config, :http_response, :passport_requested

        def initialize(http_response:, config:, passport_requested: false,
                       liveness_checking_enabled: false, request_context: {})
          @config = config
          @http_response = http_response
          @passport_requested = passport_requested
          @request_context = request_context
          @liveness_checking_enabled = liveness_checking_enabled
          @pii_from_doc = read_pii(true_id_product)
          super(
            success: successful_result?,
            errors: error_messages,
            extra: extra_attributes,
            pii_from_doc: @pii_from_doc,
          )
        rescue StandardError => e
          NewRelic::Agent.notice_error(e)
          super(
            success: false,
            errors: { network: true },
            exception: e,
            extra: {
              backtrace: e.backtrace,
              reference: reference,
            },
          )
        end

        ## returns full check success status, considering all checks:
        #    vendor (document and selfie if requested)
        def successful_result?
          return false if passport_detected_but_not_allowed?
          return false if passport_card_detected?

          doc_auth_success? &&
            (@liveness_checking_enabled ? selfie_passed? : true)
        end

        # all checks from document perspectives, without considering selfie:
        #  vendor (document only)
        #  document_type
        def doc_auth_success?
          # really it's everything else excluding selfie
          transaction_status_passed? && id_type_supported? && id_doc_type_expected?
        end

        def error_messages
          return {} if successful_result?

          if passport_detected_but_not_allowed?
            { passport: true }
          elsif passport_card_detected?
            { passport_card: true }
          elsif id_doc_type_present? && !id_doc_type_expected?
            { unexpected_id_type: true }
          elsif with_authentication_result?
            ErrorGenerator.new(config).generate_doc_auth_errors(response_info)
          elsif true_id_product.present?
            ErrorGenerator.wrapped_general_error
          else
            { network: true } # return a generic technical difficulties error to user
          end
        end

        def extra_attributes
          if with_authentication_result?
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

        def attention_with_barcode?
          return false unless doc_auth_result_attention?

          !!parsed_alerts[:failed]
            &.any? { |alert| alert[:name] == '2D Barcode Read' && alert[:result] == 'Attention' }
        end

        def billed?
          !!doc_auth_result
        end

        # @return [:success, :fail, :not_processed]
        # When selfie result is missing or not requested:
        #   return :not_processed
        # Otherwise:
        #   return :success if selfie check result == 'Pass'
        #   return :fail
        def selfie_status
          return :not_processed if selfie_result.nil? || !@liveness_checking_enabled
          selfie_result == 'Pass' ? :success : :fail
        end

        def selfie_passed?
          selfie_status == :success
        end

        private

        def conversation_id
          @conversation_id ||= parsed_response_body.dig(:Status, :ConversationId)
        end

        def request_id
          @request_id ||= parsed_response_body.dig(:Status, :RequestId)
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body).with_indifferent_access
        end

        def id_doc_type_expected?
          expected_id_type = passport_requested ? ['passport'] :
            ['drivers_license', 'state_id_card']

          expected_id_type.include?(pii_from_doc&.id_doc_type)
        end

        def id_doc_type_present?
          pii_from_doc&.id_doc_type.present?
        end

        def passport_pii?
          @passport_pii ||= ['passport', 'passport_card'].include?(pii_from_doc&.id_doc_type)
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
          address_line2_present = false
          if !passport_pii?
            address_line2_present = !pii_from_doc&.address2.blank?
          end
          log_alert_formatter = DocAuth::ProcessedAlertToLogAlertFormatter.new
          {
            transaction_status: transaction_status,
            transaction_reason_code: transaction_reason_code,
            product_status: product_status,
            decision_product_status: decision_product_status,
            doc_auth_result: doc_auth_result,
            processed_alerts: alerts,
            alert_failure_count: alerts[:failed]&.count.to_i,
            log_alert_results: log_alert_formatter.log_alerts(alerts),
            portrait_match_results: portrait_match_results,
            image_metrics: read_image_metrics(true_id_product),
            address_line2_present: address_line2_present,
            classification_info: classification_info,
            liveness_enabled: @liveness_checking_enabled,
          }
        end

        def basic_logging_info
          {
            conversation_id: conversation_id,
            request_id: request_id,
            reference: reference,
            vendor: 'TrueID',
            billed: billed?,
            workflow: @request_context&.dig(:workflow),
          }
        end

        def selfie_result
          portrait_match_results&.dig(:FaceMatchResult)
        end

        def product_status_passed?
          product_status == 'pass'
        end

        def doc_auth_result_passed?
          doc_auth_result == 'Passed'
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

        def doc_issue_type
          true_id_product&.dig(:AUTHENTICATION_RESULT, :DocIssueType)
        end

        def passport_detected_but_not_allowed?
          passport_detected = doc_class_name == 'Passport' || passport_card_detected?
          !IdentityConfig.store.doc_auth_passports_enabled && passport_detected
        end

        def passport_card_detected?
          doc_issue_type == 'Passport Card'
        end

        def classification_info
          # Acuant response has both sides info, here simulate that
          doc_class = doc_class_name
          issuing_country = pii_from_doc&.issuing_country_code
          classification_hash = {
            Front: {
              ClassName: doc_class,
              IssuerType: doc_issuer_type,
              CountryCode: issuing_country,
            },
          }
          if !passport_pii?
            classification_hash[:Back] = {
              ClassName: doc_class,
              IssuerType: doc_issuer_type,
              CountryCode: issuing_country,
            }
          end
          classification_hash
        end

        def portrait_match_results
          true_id_product&.dig(:PORTRAIT_MATCH_RESULT)
        end

        def doc_auth_result
          true_id_product&.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
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
          return @new_alerts unless with_authentication_result?
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

        def with_authentication_result?
          true_id_product&.dig(:AUTHENTICATION_RESULT).present?
        end
      end
    end
  end
end
