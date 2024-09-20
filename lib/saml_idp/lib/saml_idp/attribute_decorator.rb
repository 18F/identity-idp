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
      source[:friendly_name]
    end

    def name_format
      source[:name_format] || Saml::XML::Namespaces::Formats::Attr::URI
    end

    def values
      Array(source[:values])
    end
  end
end
