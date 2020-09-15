# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      class TrueIdResponse < LexisNexisResponse
        def initialize(http_response)
          super http_response
        end

        def successful_result?
          transaction_status_passed? &&
            product_status_passed? &&
            doc_auth_result_passed?
        end

        def error_messages
          return {} if successful_result?
        end

        def extra_attributes
          true_id_product[:AUTHENTICATION_RESULT].reject do |k, _v|
            PII_DETAILS.include? k
          end
        end

        def pii_from_doc
          true_id_product[:AUTHENTICATION_RESULT].select do |k, _v|
            PII_DETAILS.include? k
          end
        end

        private

        def transaction_status_passed?
          transaction_status == 'passed'
        end

        def product_status_passed?
          product_status == 'pass'
        end

        def doc_auth_result_passed?
          doc_auth_result == 'Passed'
        end

        def doc_auth_result
          true_id_product.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
        end

        def product_status
          true_id_product.dig(:ProductStatus)
        end

        def true_id_product
          products[:TrueID]
        end

        def detail_groups
          %w[
            AUTHENTICATION_RESULT
            IDAUTH_FIELD_DATA
            IDAUTH_FIELD_NATIVE_DATA
            IMAGE_METRICS_RESULT
            PORTRAIT_MATCH_RESULT
          ].freeze
        end
      end
    end
  end
end
