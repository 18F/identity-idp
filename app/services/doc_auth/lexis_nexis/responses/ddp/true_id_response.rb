# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      module Ddp
        class TrueIdResponse < DocAuth::Response
          include ImageMetricsReader
          include DocAuth::LexisNexis::Ddp::DocPiiReader
          include DocAuth::ClassificationConcern

          attr_reader :config, :http_response, :passport_requested

          def initialize(http_response:, config:, passport_requested: false,
                         liveness_checking_enabled: false, request_context: {}, request: nil)
            @config = config
            @http_response = http_response
            @passport_requested = passport_requested
            @request_context = request_context
            @request = request
            @liveness_checking_enabled = liveness_checking_enabled
            @pii_from_doc = read_pii
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

          # returns full check success status, considering all checks:
          # vendor (document and selfie if requested)
          # Will be further implemented in future tickets
          def successful_result?
            doc_auth_success?
          end

          def doc_auth_success?
            transaction_status_passed? && id_type_supported? && expected_document_type_received?
          end

          # To be implemented in LG-17088
          def error_messages
            successful_result? ? {} : { network: true }
          end

          # To be implemented in LG-17089
          def extra_attributes
            return {}
          end

          private

          def expected_document_type_received?
            expected_id_types = passport_requested ?
              Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES :
              Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES

            expected_id_types.include?(document_type_received)
          end

          def document_type_received
            DocumentClassifications::CLASSIFICATION_TO_DOCUMENT_TYPE[doc_class]
          end

          def parsed_response_body
            @parsed_response_body ||= JSON.parse(http_response.body).with_indifferent_access
          end

          def authentication_results
            parsed_response_body.dig(
              :integration_hub_results,
              "#{IdentityConfig.store.lexisnexis_threatmetrix_org_id}:#{policy}",
              'Authentication', 'tps_vendor_raw_response'
            )
          end

          def policy
            @policy ||= @request&.policy
          end

          def transaction_status
            authentication_results&.dig(:Status, :TransactionStatus)
          end

          def transaction_status_passed?
            transaction_status == 'passed'
          end

          def reference
            @reference ||= parsed_response_body.dig(:Status, :Reference)
          end

          def doc_class
            id_auth_field_data&.dig('Fields_DocumentClassName')
          end

          def passport_pii?
            @passport_pii ||=
              Idp::Constants::DocumentTypes::PASSPORT_TYPES.include?(doc_class)
          end

          def issuing_country_code
            id_auth_field_data&.dig('Fields_CountryCode')
          end

          def classification_info
            # Acuant response has both sides info, here simulate that
            classification_hash = {
              Front: {
                ClassName: doc_class,
                CountryCode: issuing_country_code,
              },
            }
            if !passport_pii?
              classification_hash[:Back] = {
                ClassName: doc_class,
                CountryCode: issuing_country_code,
              }
            end
            classification_hash
          end

          def products
            @products ||=
              authentication_results.dig(:Products)&.each_with_object({}) do |product, product_list|
                # puts "Processing product: #{product.inspect}"
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

          def true_id_product
            products&.dig(:TrueID)
          end

          def id_auth_field_data
            true_id_product&.dig(:IDAUTH_FIELD_DATA)
          end
        end
      end
    end
  end
end
