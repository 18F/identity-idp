# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Requests
      module Ddp
        class TrueIdRequest < DocAuth::LexisNexis::Request
          attr_reader :applicant

          def initialize(config:, user_uuid:, uuid_prefix:, applicant:)
            @applicant = applicant
            super(config: config, user_uuid: user_uuid, uuid_prefix: uuid_prefix)
          end

          def fetch
            # TODO uncomment validate images after/during manual testing
            validate_images!
            super
          end

          def policy
            if liveness_checking_required?
              IdentityConfig.store.lexisnexis_trueid_ddp_liveness_policy
            else
              IdentityConfig.store.lexisnexis_trueid_ddp_noliveness_policy
            end
          end

          private

          def handle_http_response(http_response)
            LexisNexis::Responses::Ddp::TrueIdResponse.new(
              http_response:,
              passport_requested: applicant[:passport_requested],
              config:,
              liveness_checking_enabled: liveness_checking_required?,
              request_context: request_context,
              request: self,
            )
          end

          def body
            # Guard for parent class calling build_request_body during initialize
            return {}.to_json unless required_data_present?

            {
              account_email: applicant[:email],
              policy:,
              'Trueid.image_data.white_front': encode(id_front_image),
              'Trueid.image_data.white_back': back_image_value,
              'Trueid.image_data.selfie': selfie_image_value,
              service_type: 'basic',
              local_attrib_1: applicant[:uuid_prefix] || '',
              local_attrib_3: applicant[:uuid],
            }.to_json
          end

          def request_headers
            {
              'Content-Type' => 'application/json',
              'x-org-id' => config.org_id,
              'x-api-key' => config.api_key,
            }
          end

          def method
            :post
          end

          def request_context
            {
              workflow: workflow,
              document_type_requested: applicant[:document_type_requested],
            }
          end

          def account_id
            config.trueid_account_id
          end

          def username
            config.trueid_username
          end

          def password
            config.trueid_password
          end

          def workflow
            if liveness_checking_required?
              config.trueid_liveness_nocropping_workflow
            else
              config.trueid_noliveness_cropping_workflow
            end
          end

          def url_request_path
            '/authentication/v1/trueid/'
          end

          def timeout
            IdentityConfig.store.lexisnexis_threatmetrix_timeout
          end

          def metric_name
            'lexis_nexis_ddp_trueid'
          end

          def encode(image)
            Base64.strict_encode64(image)
          end

          def back_image_value
            back_image_required? ? encode(applicant[:back_image]) : ''
          end

          def selfie_image_value
            liveness_checking_required? ? encode(applicant[:selfie_image]) : ''
          end

          def back_image_required?
            applicant[:document_type_requested] == DocumentTypes::DRIVERS_LICENSE
          end

          def liveness_checking_required?
            applicant[:liveness_checking_required] == true
          end

          def passport_document?
            applicant[:document_type_requested] == DocumentTypes::PASSPORT
          end

          def required_data_present?
            return false if applicant[:uuid].blank? || applicant[:email].blank?
            if passport_document?
              return false if applicant[:passport_image].blank?
            elsif applicant[:front_image].blank? || applicant[:back_image].blank?
              return false
            end
            return false if liveness_checking_required? && applicant[:selfie_image].blank?
            true
          end

          def id_front_image
            if applicant[:document_type_requested] == DocumentTypes::PASSPORT
              applicant[:passport_image]
            else
              applicant[:front_image]
            end
          end

          def validate_images!
            raise ArgumentError, 'uuid is required' if applicant[:uuid].blank?
            raise ArgumentError, 'email is required' if applicant[:email].blank?

            if passport_document?
              if applicant[:passport_image].blank?
                raise ArgumentError, 'passport_image is required for passport documents'
              end
            else
              raise ArgumentError, 'front_image is required' if applicant[:front_image].blank?
              raise ArgumentError, 'back_image is required' if applicant[:back_image].blank?
            end

            if liveness_checking_required? && applicant[:selfie_image].blank?
              raise ArgumentError, 'selfie_image is required when liveness checking is enabled'
            end
          end
        end
      end
    end
  end
end
