require 'httparty'
require 'saml_idp/attributeable'
require 'saml_idp/incoming_metadata'
module SamlIdp
  class ServiceProvider
    include Attributeable
    attribute :identifier
    attribute :fingerprint
    attribute :metadata_url

    delegate :config, to: :SamlIdp

    def valid?
      attributes.present?
    end

    def valid_signature?(doc)
      !should_validate_signature? ||
        doc.valid_signature?(fingerprint)
    end

    def should_validate_signature?
      false
    end

    def refresh_metadata
      fresh = fresh_incoming_metadata
      if valid_signature?(fresh.document)
        metadata_persister[fresh]
      end
    end

    def metadata_perisister
      config.service_provider.metadata_persister
    end

    def fresh_incoming_metadata
      IncomingMetadata.new request_metadata
    end
    private :fresh_incoming_metadata

    def request_metadata
      HTTParty.get(metadata_url).body
    end
    private :request_metadata
  end
end
