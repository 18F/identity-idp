module DocAuth
  module LexisNexis
    module Responses
      class TrueIdResponse < LexisNexisResponse
        def initialize(http_response)
          super http_response
        end

        def successful_result?
          transaction_status == 'passed' &&
            product_status == 'pass' &&
            doc_auth_result == 'Passed'
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

        def doc_auth_result
          @doc_auth_result ||= true_id_product.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
        end

        def true_id_product
          products[:TrueID]
        end

        def product_status
          @product_status ||= true_id_product.dig(:ProductStatus)
        end

        def detail_groups
          [
            'AUTHENTICATION_RESULT'.freeze,
            'IDAUTH_FIELD_DATA'.freeze,
            'IDAUTH_FIELD_NATIVE_DATA'.freeze,
            'IMAGE_METRICS_RESULT'.freeze,
            'PORTRAIT_MATCH_RESULT'.freeze,
          ].freeze
        end
      end
    end
  end
end
