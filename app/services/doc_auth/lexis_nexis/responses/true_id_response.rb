# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      class TrueIdResponse < LexisNexisResponse
        PII_EXCLUDES = %w[
          Age
          DocIssuerCode
          DocIssuerName
          DocIssue
          DocumentName
          DocSize
          DOB_Day
          DOB_Month
          DOB_Year
          DocIssueType
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
          'Fields_DocumentClassName' => :state_id_type,
        }.freeze
        attr_reader :config

        def initialize(http_response, liveness_checking_enabled, config)
          @liveness_checking_enabled = liveness_checking_enabled
          @config = config

          super http_response
        end

        def successful_result?
          all_passed? || attention_with_barcode?
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

          pii
        end

        def attention_with_barcode?
          return false unless doc_auth_result_attention?

          parsed_alerts[:failed]&.count.to_i == 1 &&
            parsed_alerts.dig(:failed, 0, :name) == '2D Barcode Read' &&
            parsed_alerts.dig(:failed, 0, :result) == 'Attention'
        end

        private

        def response_info
          @response_info ||= create_response_info
        end

        def create_response_info
          alerts = parsed_alerts

          {
            liveness_enabled: @liveness_checking_enabled,
            transaction_status: transaction_status,
            transaction_reason_code: transaction_reason_code,
            product_status: product_status,
            doc_auth_result: doc_auth_result,
            processed_alerts: alerts,
            alert_failure_count: alerts[:failed]&.count.to_i,
            portrait_match_results: true_id_product[:PORTRAIT_MATCH_RESULT],
            image_metrics: parse_image_metrics,
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

        def billed?
          !!doc_auth_result && !doc_auth_result_unknown?
        end

        def all_passed?
          transaction_status_passed? &&
            true_id_product.present? &&
            product_status_passed? &&
            doc_auth_result_passed?
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

        def doc_auth_result_unknown?
          doc_auth_result == 'Unknown'
        end

        def doc_auth_result
          true_id_product&.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
        end

        def product_status
          true_id_product&.dig(:ProductStatus)
        end

        def true_id_product
          products[:TrueID] if products.present?
        end

        def parsed_alerts
          return @new_alerts if defined?(@new_alerts)

          @new_alerts = { passed: [], failed: [] }
          all_alerts = true_id_product[:AUTHENTICATION_RESULT].select do |key|
            key.start_with?('Alert_')
          end

          alert_names = all_alerts.select { |key| key.end_with?('_AlertName') }
          alert_names.each do |alert_name, _v|
            alert_prefix = alert_name.scan(/Alert_\d{1,2}_/).first
            alert = combine_alert_data(all_alerts, alert_prefix)
            if alert[:result] == 'Passed'
              @new_alerts[:passed].push(alert)
            else
              @new_alerts[:failed].push(alert)
            end
          end

          @new_alerts
        end

        def combine_alert_data(all_alerts, alert_name)
          new_alert_data = {}
          # Get the set of Alerts that are all the same number (e.g. Alert_11)
          alert_set = all_alerts.select { |key| key.match?(alert_name) }

          alert_set.each do |key, value|
            new_alert_data[:alert] = alert_name.delete_suffix('_')
            new_alert_data[:name] = value if key.end_with?('_AlertName')
            new_alert_data[:result] = value if key.end_with?('_AuthenticationResult')
            new_alert_data[:region] = value if key.end_with?('_Regions')
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

        def parse_date(year:, month:, day:)
          if year.to_i.positive? && month.to_i.positive? && day.to_i.positive?
            Date.new(year.to_i, month.to_i, day.to_i).to_s
          end
        end
      end
    end
  end
end
