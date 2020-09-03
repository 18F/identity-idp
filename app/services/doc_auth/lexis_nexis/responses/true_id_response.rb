module DocAuth
  module LexisNexis
    module Responses
      class TrueIdResponse < DocAuth::Response
        attr_reader :http_response

        def initialize(http_response)
          @http_response = http_response
          super(
            success: successful_result?,
            errors: error_messages,
            extra: extra_attributes,
            pii_from_doc: pii_from_doc,
          )
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
        end

        def pii_from_doc
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body)
        end

        def transaction_status
          return @transaction_status if defined?(@transaction_status)

          @transaction_status = parsed_response_body.dig('Status', 'TransactionStatus')
        end

        def product_status
          return @product_status if defined?(@product_status)

          @product_status = true_id_product.dig('ProductStatus')
        end

        def doc_auth_result
          return @doc_auth_result if defined?(@doc_auth_result)

          @doc_auth_result = true_id_product.dig('authentication_result_details', 'DocAuthResult')
        end

        def true_id_product
          products['TrueID']
        end

        def products
          @products ||= begin
            product_list = {}
            parsed_response_body.dig('Products').each do |product|
              product['authentication_result_details'] = authentication_result_details(product)
              product_list[product['ProductType']] = product
            end
            product_list
          end
        end

        def authentication_result_details(product)
          details = {}
          product['ParameterDetails'].each do |detail|
            if detail['Group'] == 'AUTHENTICATION_RESULT'
              details[detail['Name']] = detail['Values'][0]['Value']
            end
          end
          details
        end
      end
    end
  end
end
