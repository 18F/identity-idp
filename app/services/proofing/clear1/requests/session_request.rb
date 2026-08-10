# frozen_string_literal: true

module Proofing
  module Clear1
    module Requests
      class SessionRequest < Proofing::Clear1::Request
        attr_reader :user_uuid

        def initialize(user_uuid:, redirect_url:)
          @user_uuid = user_uuid
          @redirect_url = redirect_url
        end

        private

        def http_method
          :post
        end

        def metric_name
          'clear1_session_request'
        end

        def handle_http_response(response)
          response_body = JSON.parse(response.body, symbolize_names: true)

          if success?(response_body)
            success = true
            errors = nil
          else
            success = false
            errors = { clear1: true }
          end

          FormResponse.new(
            success:,
            errors: errors,
            extra: extra_attributes.merge(
              **response_body.slice(
                :id, :object_name, :project_id, :redirect_url,
                :expires_at, :created_at, :status, :token
              ),
            ),
          )
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          FormResponse.new(
            success: false,
            errors: { clear1: true },
            extra: extra_attributes.merge(exception:),
          )
        end

        def endpoint
          [
            IdentityConfig.store.idv_clear1_api_base_url,
            'v1',
            'verification_sessions',
          ].join('/')
        end

        def request_headers
          {
            'Content-Type': 'application/json',
            Authorization: "Bearer #{IdentityConfig.store.idv_clear1_api_key}",
          }
        end

        def body
          {
            project_id: IdentityConfig.store.idv_clear1_project_id,
            redirect_url:,
            custom_fields: { user_uuid: },
          }.to_json
        end

        def success?(response_body)
          response_body[:token].present?
        end

        def extra_attributes
          {
            vendor_name: Idp::Constants::Vendors::CLEAR1,
            state:,
          }
        end

        def state
          @state ||= SecureRandom.uuid
        end

        def redirect_url
          @redirect_url + "?state=#{state}"
        end
      end
    end
  end
end
