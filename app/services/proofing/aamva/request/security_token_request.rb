# frozen_string_literal: true

require 'erb'
require 'faraday'
require 'openssl'
require 'retries'
require 'securerandom'
require 'time'
require 'xmldsig'

module Proofing
  module Aamva
    module Request
      class SecurityTokenRequest
        DEFAULT_AUTH_URL = 'https://authentication-cert.aamva.org/Authentication/Authenticate.svc'
        CONTENT_TYPE = 'application/soap+xml;charset=UTF-8'
        SOAP_ACTION =
          '"http://aamva.org/authentication/3.1.0/IAuthenticationService/Authenticate"'

        attr_reader :config, :body, :headers, :url

        def initialize(config)
          @config = config
          @url = auth_url
          @body = build_request_body
          @headers = build_request_headers
        end

        def nonce
          @nonce ||= SecureRandom.base64(32)
        end

        def send
          with_retries(max_tries: 2, rescue: [Faraday::TimeoutError, Faraday::ConnectionFailed]) do
            Response::SecurityTokenResponse.new(
              http_client.post(url, body, headers) do |req|
                req.options.context = { service_name: 'aamva_security_token' }
              end,
            )
          end
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => err
          message = "AAMVA raised #{err.class} waiting for security token response: #{err.message}"
          raise ::Proofing::TimeoutError, message
        end

        def auth_url
          config.auth_url || DEFAULT_AUTH_URL
        end

        private

        def http_client
          Faraday.new(request: { open_timeout: timeout, timeout: timeout }) do |faraday|
            faraday.request :instrumentation, name: 'request_metric.faraday'
            faraday.adapter :net_http
          end
        end

        def build_request_body
          renderer = ERB.new(request_body_template)
          xml = renderer.result(binding)
          xml = xml.gsub(/^\s+/, '').gsub(/\s+$/, '').delete("\n")
          document = Xmldsig::SignedDocument.new(xml)
          document.sign(private_key).gsub("<?xml version=\"1.0\"?>\n", '')
        end

        def build_request_headers
          {
            'SOAPAction' => SOAP_ACTION,
            'Content-Type' => CONTENT_TYPE,
            'Content-Length' => body.length.to_s,
          }
        end

        def certificate
          @certificate = public_key.to_s.gsub(/\n?-----.+-----\n/, '')
        end

        def created_at
          @created_at ||= Time.zone.now.utc
        end

        def expires_at
          created_at + 300
        end

        def key_identifier
          @key_identifier ||=
            begin
              digest = OpenSSL::Digest::SHA1.digest(public_key.to_der)
              Base64.encode64(digest)
            end.strip
        end

        def message_timestamp_uuid
          @message_timestamp_uuid ||= SecureRandom.uuid
        end

        def message_to_uuid
          @message_to_uuid ||= SecureRandom.uuid
        end

        def private_key
          @private_key ||= OpenSSL::PKey::RSA.new(
            Base64.decode64(config.private_key),
          )
        end

        def public_key
          @public_key ||= OpenSSL::X509::Certificate.new(
            Base64.decode64(config.public_key),
          )
        end

        def reply_to_uuid
          @reply_to_uuid ||= SecureRandom.uuid
        end

        def request_body_template
          template_file_path = Rails.root.join(
            'app',
            'services',
            'proofing',
            'aamva',
            'request',
            'templates',
            'security_token.xml.erb',
          )
          File.read(template_file_path)
        end

        def uuid
          SecureRandom.uuid
        end

        def timeout
          (config.auth_request_timeout || 5).to_i
        end
      end
    end
  end
end
