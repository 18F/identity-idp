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
          #AM: This doesn't really work yet, I don't think. We'll need to make sure things get wrapped up there.
          handle_invalid_response(http_response) unless http_response.status == 200

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
              # detail_groups.each do |group|
              #   product[group] = product_details(product: product, group: group)
              # end
              puts "\n\n\n\n\n"
              extract_details(product)
              product_list[product[:ProductType]] = product
              puts "\n\n\n\n\n"
              detail_groups.each do |group|
                puts "\nproduct_list[product[:ProductType]][#{group}]:"
                pp product_list[product[:ProductType]][group]
              end
              puts "\n\n\n\n\n"
            end
            product_list.with_indifferent_access
          end
        end

        # def product_details(product:, group:)
        #   details = {}
        #   product[:ParameterDetails].each do |detail|
        #     if detail[:Group] == group
        #       details[detail[:Name]] = detail[:Values][0][:Value]
        #     end
        #   end
        #   details.with_indifferent_access
        # end

        def extract_details(product)
          product[:ParameterDetails].each do |detail|
            group = detail[:Group]
            detail_name = detail[:Name]
            value = detail[:Values][0][:Value]

            product[group] = {} unless product[group]

            product[group][detail_name] = value
          end
        end

        def handle_invalid_response(http_response)
          message = [
            self.class.name,
            'Unexpected HTTP response',
            http_response.status,
          ].join(' ')

          exception = RuntimeError.new(message)
          NewRelic::Agent.notice_error(exception)
          DocAuth::Response.new(
            success: false,
            errors: { network: I18n.t('errors.doc_auth.lexisnexis_network_error') },
            exception: exception,
            )
        end
      end
    end
  end
end
