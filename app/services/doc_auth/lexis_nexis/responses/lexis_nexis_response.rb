# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      class LexisNexisResponse < DocAuth::Response
        attr_reader :http_response

        def initialize(http_response)
          @http_response = http_response

          super(
            success: successful_result?,
            errors: error_messages,
            extra: extra_attributes,
            pii_from_doc: pii_from_doc,
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
          raise NotImplementedError
        end

        def error_messages
          raise NotImplementedError
        end

        def extra_attributes
          raise NotImplementedError
        end

        def pii_from_doc
          raise NotImplementedError
        end

        def classification_info
          raise NotImplementedError
        end

        private

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body).with_indifferent_access
        end

        def transaction_status_passed?
          transaction_status == 'passed'
        end

        def transaction_status
          parsed_response_body.dig(:Status, :TransactionStatus)
        end

        def transaction_reason_code
          @transaction_reason_code ||=
            parsed_response_body.dig(:Status, :TransactionReasonCode, :Code)
        end

        def conversation_id
          @conversation_id ||= parsed_response_body.dig(:Status, :ConversationId)
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
      end
    end
  end
end
