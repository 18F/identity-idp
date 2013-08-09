require 'httparty'
require 'saml_idp/attributeable'
require 'saml_idp/incoming_metadata'
module SamlIdp
  class ServiceProvider
    include Attributeable
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
      fresh = fresh_metadata_document
      if valid_signature?(fresh)
      end
    end

    def fresh_metadata_document
      Saml::XML::Document.parse request_metadata
    end

    def request_metadata
      HTTParty.get(metadata_url).body
    end
    private :request_metadata
  end
end
