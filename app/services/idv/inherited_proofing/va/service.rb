module Idv
  module InheritedProofing
    module Va
      # Encapsulates request, response, error handling, validation, etc. for calling
      # the VA service to gain PII for a particular user that will be subsequently
      # used to proof the user using inherited proofing.
      class Service
        BASE_URI = IdentityConfig.store.inherited_proofing_va_base_url

        attr_reader :auth_code

        def initialize(service_provider_data)
          @auth_code = service_provider_data[:auth_code]
        end

        # Calls the endpoint and returns the decrypted response.
        def execute
          raise 'The provided auth_code is blank?' if auth_code.blank?

          response = request
          payload_to_hash decrypt_payload(response)
        end

        private

        def request
          connection.get(request_uri) { |req| req.headers = request_headers }
        end

        def connection
          Faraday.new do |conn|
            conn.options.timeout = request_timeout
            conn.options.read_timeout = request_timeout
            conn.options.open_timeout = request_timeout
            conn.options.write_timeout = request_timeout
            conn.request :instrumentation, name: 'inherited_proofing.va'

            # raises errors on 4XX or 5XX responses
            conn.response :raise_error
          end
        end

        def request_timeout
          @request_timeout ||= IdentityConfig.store.doc_auth_s3_request_timeout
        end

        def request_uri
          @request_uri ||= "#{ URI(BASE_URI) }/inherited_proofing/user_attributes"
        end

        def request_headers
          { Authorization: "Bearer #{jwt_token}" }
        end

        def jwt_token
          JWT.encode(jwt_payload, private_key, jwt_encryption)
        end

        def jwt_payload
          { inherited_proofing_auth: auth_code, exp: jwt_expires }
        end

        def private_key
          @private_key ||= AppArtifacts.store.oidc_private_key
        end

        def jwt_encryption
          'RS256'
        end

        def jwt_expires
          1.day.from_now.to_i
        end

        def decrypt_payload(response)
          payload = JSON.parse(response.body)['data']
          JWE.decrypt(payload, private_key) if payload
        end

        def payload_to_hash(decrypted_payload, default: nil)
          return default unless decrypted_payload.present?

          JSON.parse(decrypted_payload, symbolize_names: true)
        end
      end
    end
  end
end
