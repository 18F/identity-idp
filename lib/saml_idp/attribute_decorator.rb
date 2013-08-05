require 'delegate'
module SamlIdp
  class AttributeDecorator < SimpleDelegator
    alias_method :source, :__getobj__

    def initialize(*)
      super
      __setobj__((source || {}).with_indifferent_access)
    end

    def name
      source[:name]
    end

    def friendly_name
      soruce[:friendly_name]
    end

    def name_format
      source[:name_format] || "urn:oasis:names:tc:SAML:2.0:attrname-format:uri"
    end

    def values
      source[:values]
    end
  end
end
