require 'faraday'
require 'saml_idp/attributeable'
require 'saml_idp/incoming_metadata'
require 'saml_idp/persisted_metadata'
module SamlIdp
  class ServiceProvider
    include Attributeable
    attribute :identifier
    attribute :certs
    attribute :metadata_url
    attribute :validate_signature
    attribute :acs_url
    attribute :assertion_consumer_logout_service_url

    delegate :config, to: :SamlIdp

    def valid?
      attributes.present?
    end

    def valid_signature?(matching_cert = nil, require_signature = false)
      if require_signature || should_validate_signature?
        matching_cert.present?
      else
        true
      end
    end

    # @param [OpenSSL::X509::Certificate] ssl_cert
    def fingerprint_cert(ssl_cert)
      OpenSSL::Digest::SHA256.new(ssl_cert.to_der).hexdigest
    end

    def should_validate_signature?
      attributes[:validate_signature] ||
        (current_metadata.respond_to?(:sign_assertions?) && current_metadata.sign_assertions?)
    end

    def refresh_metadata
      fresh = fresh_incoming_metadata
      return unless valid_signature?(fresh.document)

      metadata_persister[identifier, fresh]
      @current_metadata = nil
      fresh
    end

    def current_metadata
      @current_metadata ||= get_current_or_build
    end

    def get_current_or_build
      persisted = metadata_getter[identifier, self]
      return unless persisted.is_a? Hash

      PersistedMetadata.new(persisted)
    end
    private :get_current_or_build

    def metadata_getter
      config.service_provider.persisted_metadata_getter
    end
    private :metadata_getter

    def metadata_persister
      config.service_provider.metadata_persister
    end
    private :metadata_persister

    def fresh_incoming_metadata
      IncomingMetadata.new request_metadata
    end
    private :fresh_incoming_metadata

    def request_metadata
      metadata_url.present? ? Faraday.get(metadata_url).body : ''
    end
    private :request_metadata
  end
end
