# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Ddp
      class Client < Proofing::LexisNexis::Request

        VALID_REVIEW_STATUSES = %w[pass review reject].freeze

        def initialize(attrs)
          config = Proofing::LexisNexis::Config.new(attrs)
          super(config:, applicant: {})
        end

        def post_images(
          document_type_requested:,
          passport_requested:,
          liveness_checking_required:,
          front_image:,
          back_image:,
          passport_image: nil,
          selfie_image: nil,
          image_source: nil,
          images_cropped: false,
          uuid_prefix: nil,
          user_uuid: nil
        )
          @front_image = front_image
          @back_image = back_image
          @passport_image = passport_image
          @selfie_image = selfie_image
          @document_type_requested = document_type_requested
          @passport_requested = passport_requested
          @liveness_checking_required = liveness_checking_required
          @image_source = image_source
          @images_cropped = images_cropped
          @user_uuid = user_uuid
          @uuid_prefix = uuid_prefix 

          @body = build_request_body

          applicant[ :uuid ] = user_uuid
          applicant[ :uuid_prefix ] = uuid_prefix

          response = send_request
          # puts response.response_body
          build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          Proofing::DdpResult.new(success: false, exception: exception)
        end

        private

        attr_reader :front_image, :back_image, :selfie_image, :passport_image, :document_type_requested,
                    :passport_requested, :liveness_checking_required, :user_uuid, :uuid_prefix

        def build_request_body
          return {} if front_image.blank? # parent class calls on initialize
          {
            # api_key: config.api_key,
            # org_id: config.org_id,
            'Trueid.image_data.white_front': encode(id_front_image),
            'Trueid.image_data.white_back': back_image_required? ? encode(back_image) : '',
            'Trueid.image_data.selfie': (liveness_checking_required ? encode(selfie_image) : ''),
            account_email: applicant[:email],
            # customer_event_type: applicant[:workflow],
            event_type: 'ACCOUNT_CREATION',
            policy:,
            service_type: 'basic',
            # session_id: applicant[:threatmetrix_session_id],
            local_attrib_1: applicant[:uuid_prefix] || '',
            local_attrib_3: applicant[:uuid],
            auth_method: 'trueid',
          }.to_json
        end

        def policy
          if liveness_checking_required
            return IdentityConfig.store.lexisnexis_trueid_liveness_nocropping_policy
          end

          IdentityConfig.store.lexisnexis_trueid_noliveness_nocropping_policy
        end

        def metric_name
          'lexis_nexis_ddp_trueid'
        end

        def url_request_path
          '/authentication/v1/trueid/'
        end

        def timeout
          IdentityConfig.store.lexisnexis_threatmetrix_timeout
        end

        def encode(image)
          Base64.strict_encode64(image)
        end

        def back_image_required?
          document_type_requested == DocumentTypes::DRIVERS_LICENSE
        end

        def id_front_image
          # TrueID front_image required whether driver's license or passport
          case document_type_requested
          when DocumentTypes::PASSPORT
            passport_image
          else
            front_image
          end
        end

        def build_result_from_response(verification_response) # Todo: update to DDP::TrueIDResult
          result = Proofing::DdpResult.new
          body = verification_response.response_body

          result.response_body = body
          result.transaction_id = body['request_id']
          request_result = body['request_result']
          review_status = body['review_status']

          validate_review_status!(review_status)

          result.review_status = review_status
          result.add_error(:request_result, request_result) unless request_result == 'success'
          result.add_error(:review_status, review_status) unless review_status == 'pass'
          result.account_lex_id = body['account_lex_id']
          result.session_id = body['session_id']

          result.success = !result.errors? # or is pass enough?
          result.client = 'lexisnexis'

          result
        end

        def validate_review_status!(review_status)
          return if VALID_REVIEW_STATUSES.include?(review_status)

          raise "Unexpected ThreatMetrix review_status value: #{review_status}"
        end

        def build_request_headers
          {
            'Content-Type' => 'application/json',
            'x-org-id' => config.org_id,
            'x-api-key' => config.api_key,
          }
        end
      end
    end
  end
end
