# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Requests
      module Ddp
        class TrueIdRequest < Proofing::LexisNexis::Request
          VALID_REVIEW_STATUSES = %w[pass review reject].freeze

          attr_reader :config

          def initialize(config:)
            @config = config
            @applicant = {}
            super(config: config, applicant: @applicant)
          end

          def proof(
            front_image:,
            back_image:,
            document_type_requested:,
            applicant: {},
            selfie_image: nil,
            passport_image: nil,
            liveness_checking_required: false
          )
            @front_image = front_image
            @back_image = back_image
            @passport_image = passport_image
            @selfie_image = selfie_image
            @document_type_requested = document_type_requested
            @liveness_checking_required = liveness_checking_required
            @applicant = applicant

            validate_images!

            @body = build_request_body
            @headers = build_request_headers
            @url = build_request_url

            response = send_request
            build_result_from_response(response)
          rescue StandardError => exception
            NewRelic::Agent.notice_error(exception)
            Proofing::DdpResult.new(success: false, exception: exception)
          end

          private

          attr_reader :front_image, :back_image, :selfie_image, :passport_image,
                      :document_type_requested, :liveness_checking_required

          def build_request_body
            # The parent class calls build_request_body during initialize, before proof() sets
            # the image instance variables. Return empty JSON in that case. During actual proof()
            # calls, validate_images! ensures front_image is present before we reach this method.
            return {}.to_json if front_image.blank?

            {
              org_id: config.org_id,
              api_key: config.api_key,
              account_first_name: applicant[:first_name] || '',
              account_middle_name: applicant[:middle_name] || '',
              account_last_name: applicant[:last_name] || '',
              account_date_of_birth: format_dob(applicant[:dob]),
              account_address_street1: applicant[:address1] || '',
              account_address_street2: applicant[:address2] || '',
              account_address_city: applicant[:city] || '',
              account_address_state: applicant[:state] || '',
              account_address_zip: applicant[:zipcode] || '',
              account_address_country: address_present? ? 'us' : '',
              national_id_number: applicant[:ssn]&.gsub(/\D/, '') || '',
              national_id_type: applicant[:ssn].present? ? 'US_SSN' : '',
              account_email: applicant[:email] || '',
              policy: policy,
              'trueid.white_front': encode(id_front_image),
              'trueid.white_back': back_image_required? ? encode(back_image) : '',
              'trueid.selfie': liveness_checking_required ? encode(selfie_image) : '',
            }.to_json
          end

          def build_request_headers
            {
              'Content-Type' => 'application/json',
            }
          end

          def url_request_path
            '/authentication/v1/trueid/'
          end

          def policy
            if liveness_checking_required
              IdentityConfig.store.lexisnexis_trueid_ddp_liveness_policy
            else
              IdentityConfig.store.lexisnexis_trueid_ddp_noliveness_policy
            end
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

          def format_dob(dob)
            return '' if dob.blank?
            date = dob.respond_to?(:strftime) ? dob : Date.parse(dob)
            date.strftime('%Y%m%d')
          end

          def back_image_required?
            document_type_requested == DocumentTypes::DRIVERS_LICENSE
          end

          def address_present?
            applicant[:address1].present? || applicant[:city].present? ||
              applicant[:state].present? || applicant[:zipcode].present?
          end

          def id_front_image
            case document_type_requested
            when DocumentTypes::PASSPORT
              passport_image
            else
              front_image
            end
          end

          def build_result_from_response(verification_response)
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

            result.success = !result.errors?
            result.client = 'lexisnexis'

            result
          end

          def validate_review_status!(review_status)
            return if VALID_REVIEW_STATUSES.include?(review_status)

            raise "Unexpected review_status value: #{review_status}"
          end

          def validate_images!
            if document_type_requested == DocumentTypes::PASSPORT
              if passport_image.blank?
                raise ArgumentError, 'passport_image is required for passport documents'
              end
            else
              raise ArgumentError, 'front_image is required' if front_image.blank?
              raise ArgumentError, 'back_image is required' if back_image.blank?
            end

            if liveness_checking_required && selfie_image.blank?
              raise ArgumentError, 'selfie_image is required when liveness checking is enabled'
            end
          end
        end
      end
    end
  end
end
