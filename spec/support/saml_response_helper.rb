require_relative 'saml_auth_helper'
module SamlResponseHelper
  class XmlDoc
    include SamlAuthHelper

    def initialize(test_type, assertion_type, response = nil)
      @test_type = test_type
      @assertion_type = assertion_type
      @response = response
    end

    def original_encrypted?
      response_doc # trigger detection
      @original_encrypted
    end

    def xml_response
      Base64.decode64(Capybara.current_session.find(
        "//input[@id='#{input_id}']", visible: false
      ).value)
    end

    def input_id
      return 'SAMLRequest' if @assertion_type == 'request_assertion'

      'SAMLResponse'
    end

    def raw_xml_response
      if @test_type == 'feature'
        xml_response
      else
        @response.body
      end
    end

    def response_doc
      if raw_xml_response =~ /EncryptedData/
        @original_encrypted = true
        Nokogiri::XML(
          OneLogin::RubySaml::Response.new(
            raw_xml_response,
            settings: sp1_saml_settings
          ).decrypted_document.to_s
        )
      else
        @original_encrypted = false
        Nokogiri::XML(raw_xml_response)
      end
    end

    def response_assertion_nodeset
      response_doc.xpath(
        '//samlp:Response/saml:Assertion',
        samlp: Saml::XML::Namespaces::PROTOCOL,
        saml: Saml::XML::Namespaces::ASSERTION
      )
    end

    def response_session_index_assertion
      response_doc.xpath(
        '//samlp:Response/saml:Assertion/saml:AuthnStatement/@SessionIndex',
        samlp: Saml::XML::Namespaces::PROTOCOL,
        saml: Saml::XML::Namespaces::ASSERTION
      ).to_s
    end

    def response_assertion
      response_assertion_nodeset[0]
    end

    def request_assertion
      response_doc.xpath(
        '//samlp:LogoutRequest',
        samlp: Saml::XML::Namespaces::PROTOCOL,
        saml: Saml::XML::Namespaces::ASSERTION
      )[0]
    end

    def logout_status_assertion
      response_doc.xpath(
        '//samlp:LogoutResponse/samlp:Status/samlp:StatusCode/@Value',
        samlp: Saml::XML::Namespaces::PROTOCOL,
        saml: Saml::XML::Namespaces::ASSERTION
      ).first.content
    end

    def logout_assertion
      response_doc.xpath(
        '//samlp:LogoutResponse',
        samlp: Saml::XML::Namespaces::PROTOCOL,
        saml: Saml::XML::Namespaces::ASSERTION
      ).first
    end

    def logout_asserted_session_index
      response_doc.xpath('//samlp:LogoutRequest/samlp:SessionIndex',
                         samlp: Saml::XML::Namespaces::PROTOCOL,
                         saml: Saml::XML::Namespaces::ASSERTION)[0].content
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

    def signature_nodeset
      send(@assertion_type).xpath('./ds:Signature', ds: Saml::XML::Namespaces::SIGNATURE)
    end

    def signature
      signature_nodeset[0]
    end

    def signature_method_nodeset
      signature.xpath(
        './ds:SignedInfo/ds:SignatureMethod',
        ds: Saml::XML::Namespaces::SIGNATURE
      )
    end

    def digest_method_nodeset
      signature.xpath(
        './ds:SignedInfo/ds:Reference/ds:DigestMethod',
        ds: Saml::XML::Namespaces::SIGNATURE
      )
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
          ds: Saml::XML::Namespaces::METADATA
        ).first.content
    end

    def attribute_authority_organization_nodeset
      metadata.xpath(
        './ds:AttributeAuthorityDescriptor/ds:Organization',
        ds: Saml::XML::Namespaces::METADATA
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
          ds: Saml::XML::Namespaces::METADATA
        ).first.content
    end

    def mobile_number
      response_doc.at(
        '//ds:Attribute[@Name="mobile"]',
        ds: Saml::XML::Namespaces::ASSERTION
      )
    end

    def assertion_statement_node
      response_doc.xpath(
        '//samlp:Response/saml:Assertion/saml:AuthnStatement',
        samlp: Saml::XML::Namespaces::PROTOCOL,
        saml: Saml::XML::Namespaces::ASSERTION
      )[0]
    end

    def asserted_session_index
      response_doc.xpath('//samlp:LogoutRequest/samlp:SessionIndex',
                         samlp: Saml::XML::Namespaces::PROTOCOL,
                         saml: Saml::XML::Namespaces::ASSERTION)[0].content
    end
  end

  def decrypted_saml_response
    @decrypted_saml_response ||= Saml::XML::Document.parse(saml_response.document.to_s)
  end

  def saml_response
    OneLogin::RubySaml::Response.new(
      Nokogiri::HTML(response.body).at_css('#SAMLResponse')['value'],
      settings: saml_settings
    )
  end

  def issuer
    decrypted_saml_response.at(
      '//response:Response/ds:Issuer',
      ds: Saml::XML::Namespaces::ASSERTION,
      response: Saml::XML::Namespaces::PROTOCOL
    )
  end

  def status
    decrypted_saml_response.at('//ds:Status', ds: Saml::XML::Namespaces::PROTOCOL)
  end

  def status_code
    decrypted_saml_response.at('//ds:StatusCode', ds: Saml::XML::Namespaces::PROTOCOL)
  end

  def transform(algorithm)
    decrypted_saml_response.at(
      "//ds:Transform[@Algorithm='#{algorithm}']",
      ds: Saml::XML::Namespaces::SIGNATURE
    )
  end
end
