module DocAuth
  module LexisNexis
    module Responses
      class LexisNexisResponse < DocAuth::Response
        PII_DETAILS = %w[
          Age
          DocIssuerCode
          DocIssuerName
          DocumentName
          DOB_Day
          DOB_Month
          DOB_Year
          FullName
          Sex
          Fields_Address
          Fields_AddressLine1
          Fields_AddressLine2
          Fields_City
          Fields_State
          Fields_PostalCode
          Fields_Height
        ].map(&:freeze).freeze
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

        private

        def detail_groups
          raise NotImplementedError
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body).with_indifferent_access
        end

        def status
          @status ||= parsed_response_body.dig(:Status)
        end

        def conversation_id
          @conversation_id ||= status.dig(:ConversationId)
        end

        def reference
          @reference ||= status.dig(:Reference)
        end

        def transaction_status
          @transaction_status ||= status.dig(:TransactionStatus)
        end

        def products
          @products ||= begin
            product_list = {}
            parsed_response_body.dig(:Products).each do |product|
              extract_details(product)
              product_list[product[:ProductType]] = product
            end
            product_list.with_indifferent_access
          end
        end

        def extract_details(product)
          return unless product[:ParameterDetails]

          product[:ParameterDetails].each do |detail|
            group = detail[:Group]
            detail_name = detail[:Name]
            value = detail.dig(:Values, 0, :Value)
            product[group] ||= {}

            product[group][detail_name] = value
          end
        end
      end
    end
  end
end
