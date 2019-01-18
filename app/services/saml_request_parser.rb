class SamlRequestParser
  URI_PATTERN = Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF

  def initialize(request)
    @request = request
  end

  def requested_attributes
    return unless authn_context_attr_nodes.any?
    authn_context_attr_nodes.join(':').gsub(URI_PATTERN, '').split(/\W+/).compact.uniq
  end

  private

  attr_reader :request

  def authn_context_attr_nodes
    @_attr_nodes ||= begin
      doc = Saml::XML::Document.parse(request.raw_xml)
      doc.xpath(
        '//samlp:AuthnRequest/samlp:RequestedAuthnContext/saml:AuthnContextClassRef',
        samlp: Saml::XML::Namespaces::PROTOCOL,
        saml: Saml::XML::Namespaces::ASSERTION,
      ).select do |node|
        node.content =~ /#{Regexp.escape(URI_PATTERN)}/
      end
    end
  end
end
