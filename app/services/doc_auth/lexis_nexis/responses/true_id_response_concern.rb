# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      module TrueIdResponseConcern
        private

        def expected_id_type
          passport_requested ?
            Idp::Constants::DocumentTypes::PASSPORT :
            Idp::Constants::DocumentTypes::DRIVERS_LICENSE
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body).with_indifferent_access
        end

        def products
          {} # to be implemented by the response classes
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

        def true_id_product
          products&.dig(:TrueID)
        end

        def with_authentication_result?
          true_id_product&.dig(:AUTHENTICATION_RESULT).present?
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

        def passport_card_detected?
          doc_issue_type == 'Passport Card'
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

        def parsed_alerts
          return @new_alerts if defined?(@new_alerts)

          @new_alerts = { passed: [], failed: [] }
          return @new_alerts unless with_authentication_result?
          all_alerts = true_id_product&.dig(:AUTHENTICATION_RESULT)&.select do |key|
            key.start_with?('Alert_')
          end || []

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
      end
    end
  end
end
