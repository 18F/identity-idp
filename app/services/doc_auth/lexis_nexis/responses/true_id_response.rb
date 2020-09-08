module DocAuth
  module LexisNexis
    module Responses
      class TrueIdResponse < LexisNexisResponse

        def initialize(http_response)
          super http_response
        end

         # private

        def successful_result?
          transaction_status == 'passed' &&
            product_status == 'pass' &&
            doc_auth_result == 'Passed'
        end

        def error_messages
          return {} if successful_result?
        end

        def extra_attributes
          true_id_product[:AUTHENTICATION_RESULT].delete_if do |k, _v|
            PII_DETAILS.include? k
          end
        end

        def pii_from_doc
          true_id_product[:AUTHENTICATION_RESULT].keep_if do |k, _v|
            PII_DETAILS.include? k
          end
        end

        def transaction_status
          return @transaction_status if defined?(@transaction_status)

          @transaction_status = parsed_response_body.dig(:Status, :TransactionStatus)
        end

        def product_status
          return @product_status if defined?(@product_status)

          @product_status = true_id_product.dig(:ProductStatus)
        end

        def doc_auth_result
          return @doc_auth_result if defined?(@doc_auth_result)

          @doc_auth_result = true_id_product.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
        end

        def true_id_product
          products[:TrueID]
        end

        def detail_groups
          [
            'AUTHENTICATION_RESULT'.freeze,
            'IDAUTH_FIELD_DATA'.freeze,
            'IDAUTH_FIELD_NATIVE_DATA'.freeze,
            'PORTRAIT_MATCH_RESULT'.freeze,
          ].freeze
        end
      end
    end
  end
end
