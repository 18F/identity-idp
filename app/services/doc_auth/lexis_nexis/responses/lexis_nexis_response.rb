module DocAuth
  module LexisNexis
    module Responses
      class LexisNexisResponse < DocAuth::Response
        PII_DETAILS = [
          'Age'.freeze,
          'DocIssuerCode'.freeze,
          'DocIssuerName'.freeze,
          'DocumentName'.freeze,
          'DOB_Day'.freeze,
          'DOB_Month'.freeze,
          'DOB_Year'.freeze,
          'FullName'.freeze,
          'Sex'.freeze,
          'Fields_Address'.freeze,
          'Fields_AddressLine1'.freeze,
          'Fields_AddressLine2'.freeze,
          'Fields_City'.freeze,
          'Fields_State'.freeze,
          'Fields_PostalCode'.freeze,
          'Fields_Height'.freeze,
        ].freeze
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

        def detail_groups
          raise NotImplementedError
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body).with_indifferent_access
        end

        def products
          @products ||= begin
            product_list = {}
            parsed_response_body.dig(:Products).each do |product|
              detail_groups.each do |group|
                product[group] = product_details(product: product, group: group)
              end
              product_list[product[:ProductType]] = product
            end
            product_list.with_indifferent_access
          end
        end

        def product_details(product:, group:)
          details = {}
          product[:ParameterDetails].each do |detail|
            if detail[:Group] == group
              details[detail[:Name]] = detail[:Values][0][:Value]
            end
          end
          details.with_indifferent_access
        end
      end
    end
  end
end
