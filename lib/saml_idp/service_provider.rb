require 'httparty'
module SamlIdp
  class ServiceProvider
    def self.expose_attribute(att)
      define_method(att) { attributes[att] }
    end

    attr_accessor :attributes
    expose_attribute :fingerprint
    expose_attribute :metadata_url

    def initialize(attributes = {})
      self.attributes = (attributes || {}).with_indifferent_access
    end

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
  end
end
