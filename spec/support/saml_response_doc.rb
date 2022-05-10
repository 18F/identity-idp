require_relative 'saml_auth_helper'

class SamlResponseDoc
  include SamlAuthHelper

  attr_reader :original_encrypted

  def initialize(test_type, assertion_type, response = nil)
    @test_type = test_type
    @assertion_type = assertion_type
    @response = response
  end

  def original_encrypted?
    response_doc # trigger detection
    original_encrypted
  end

  def xml_response
    Base64.decode64(Capybara.current_session.find("##{input_id}", visible: false).value)
  end

  def html_response
    Base64.decode64(Nokogiri::HTML(@response.body).at_css('#SAMLResponse')['value'])
  end

  def input_id
    return 'SAMLRequest' if @assertion_type == 'request_assertion'

    'SAMLResponse'
  end

  def raw_xml_response
    if @test_type == 'feature'
      xml_response
    elsif @response.body.match?(/<html>/)
      html_response
    else
      @response.body
    end
  end

  def saml_response(settings)
    @saml_response ||= OneLogin::RubySaml::Response.new(
      raw_xml_response,
      settings: settings,
    )
  end

  def saml_document
    @saml_document ||= Saml::XML::Document.parse(raw_xml_response)
  end

  def response_doc
    if raw_xml_response.match?(/EncryptedData/)
      @original_encrypted = true
      Nokogiri::XML(
        OneLogin::RubySaml::Response.new(
          raw_xml_response,
          settings: saml_settings(
            overrides: { issuer: sp1_issuer },
          ),
        ).decrypted_document.to_s,
      )
    else
      @original_encrypted = false
      Nokogiri::XML(raw_xml_response)
    end
  end

  def status_code
    @status_code ||= status.xpath('//samlp:StatusCode', samlp: Saml::XML::Namespaces::PROTOCOL)
  end

  def status
    @status ||= response_doc.xpath('//samlp:Status', samlp: Saml::XML::Namespaces::PROTOCOL)
  end

  def response_assertion_nodeset
    response_doc.xpath(
      '//samlp:Response/saml:Assertion',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION,
    )
  end

  def response_session_index_assertion
    response_doc.xpath(
      '//samlp:Response/saml:Assertion/saml:AuthnStatement/@SessionIndex',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION,
    ).to_s
  end

  def response_assertion
    response_assertion_nodeset[0]
  end

  def request_assertion
    response_doc.xpath(
      '//samlp:LogoutRequest',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION,
    )[0]
  end

  def logout_status_assertion
    response_doc.xpath(
      '//samlp:LogoutResponse/samlp:Status/samlp:StatusCode/@Value',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION,
    ).first.content
  end

  def logout_assertion
    response_doc.xpath(
      '//samlp:LogoutResponse',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION,
    ).first
  end

  def logout_asserted_session_index
    response_doc.xpath(
      '//samlp:LogoutRequest/samlp:SessionIndex',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION,
    )[0].content
  end

  def issuer_nodeset
    send(@assertion_type).xpath('./saml:Issuer', saml: Saml::XML::Namespaces::ASSERTION)
  end

  def metadata_nodeset
    response_doc.xpath('//samlp:EntityDescriptor', samlp: Saml::XML::Namespaces::METADATA)
  end

  def metadata
    metadata_nodeset[0]
  end

  def metadata_name_id_format(name)
    metadata.xpath(
      "./ds:IDPSSODescriptor/ds:NameIDFormat[contains(text(), '#{name}')]",
      ds: Saml::XML::Namespaces::METADATA,
    ).first.content
  end

  def signature_nodeset
    send(@assertion_type).xpath('./ds:Signature', ds: Saml::XML::Namespaces::SIGNATURE)
  end

  def signature
    signature_nodeset[0]
  end

  def signed_info_nodeset
    signature.xpath('./ds:SignedInfo', ds: Saml::XML::Namespaces::SIGNATURE)
  end

  def signature_method_nodeset
    signature.xpath(
      './ds:SignedInfo/ds:SignatureMethod',
      ds: Saml::XML::Namespaces::SIGNATURE,
    )
  end

  def signature_canon_method_nodeset
    signature.xpath(
      './ds:SignedInfo/ds:CanonicalizationMethod',
      ds: Saml::XML::Namespaces::SIGNATURE,
    )
  end

  def digest_method_nodeset
    signature.xpath(
      './ds:SignedInfo/ds:Reference/ds:DigestMethod',
      ds: Saml::XML::Namespaces::SIGNATURE,
    )
  end

  def transforms_nodeset
    @transforms_nodeset ||= response_doc.xpath(
      '//ds:Reference/ds:Transforms',
      ds: Saml::XML::Namespaces::SIGNATURE,
    )
  end

  def transform(algorithm)
    transforms_nodeset[0].xpath(
      "//ds:Transform[@Algorithm='#{algorithm}']",
      ds: Saml::XML::Namespaces::SIGNATURE,
    )[0]
  end

  def subject_nodeset
    response_doc.xpath(
      '//ds:Subject',
      ds: Saml::XML::Namespaces::ASSERTION,
    )
  end

  def conditions_nodeset
    response_doc.xpath('//ds:Conditions', ds: Saml::XML::Namespaces::ASSERTION)
  end

  def organization_nodeset
    metadata.xpath('./ds:Organization', ds: Saml::XML::Namespaces::METADATA)
  end

  def organization_name
    organization_nodeset[0].
      xpath('./ds:OrganizationName', ds: Saml::XML::Namespaces::METADATA)[0].content
  end

  def organization_display_name
    organization_nodeset[0].
      xpath(
        './ds:OrganizationDisplayName',
        ds: Saml::XML::Namespaces::METADATA,
      ).first.content
  end

  def attribute_authority_organization_nodeset
    metadata.xpath(
      './ds:AttributeAuthorityDescriptor/ds:Organization',
      ds: Saml::XML::Namespaces::METADATA,
    )
  end

  def attribute_authority_organization_name
    attribute_authority_organization_nodeset[0].
      xpath('./ds:OrganizationName', ds: Saml::XML::Namespaces::METADATA)[0].content
  end

  def attribute_authority_organization_display_name
    attribute_authority_organization_nodeset[0].
      xpath(
        './ds:OrganizationDisplayName',
        ds: Saml::XML::Namespaces::METADATA,
      ).first.content
  end

  def phone_number
    response_doc.at(
      '//ds:Attribute[@Name="phone"]',
      ds: Saml::XML::Namespaces::ASSERTION,
    )
  end

  def uuid
    response_doc.at(
      '//ds:Attribute[@Name="uuid"]',
      ds: Saml::XML::Namespaces::ASSERTION,
    ).children.children.to_s
  end

  def attribute_node_for(name)
    response_doc.at(
      %(//ds:Attribute[@Name="#{name}"]),
      ds: Saml::XML::Namespaces::ASSERTION,
    )
  end

  def attribute_value_for(name)
    attribute_node_for(name).children.children.to_s
  end

  def assertion_statement_node
    response_doc.xpath(
      '//samlp:Response/saml:Assertion/saml:AuthnStatement',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION,
    )[0]
  end

  def asserted_session_index
    response_doc.xpath(
      '//samlp:LogoutRequest/samlp:SessionIndex',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION,
    )[0].content
  end
end
