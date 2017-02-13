# The contents of this file are subject to the terms
# of the Common Development and Distribution License
# (the License). You may not use this file except in
# compliance with the License.
#
# You can obtain a copy of the License at
# https://opensso.dev.java.net/public/CDDLv1.0.html or
# opensso/legal/CDDLv1.0.txt
# See the License for the specific language governing
# permission and limitations under the License.
#
# When distributing Covered Code, include this CDDL
# Header Notice in each file and include the License file
# at opensso/legal/CDDLv1.0.txt.
# If applicable, add the following below the CDDL Header,
# with the fields enclosed by brackets [] replaced by
# your own identifying information:
# "Portions Copyrighted [year] [name of copyright owner]"
#
# $Id: xml_sec.rb,v 1.6 2007/10/24 00:28:41 todddd Exp $
#
# Copyright 2007 Sun Microsystems Inc. All Rights Reserved
# Portions Copyrighted 2007 Todd W Saxton.

require "rexml/document"
require "rexml/xpath"
require "openssl"
require 'nokogiri'
require "digest/sha1"
require "digest/sha2"

module SamlIdp
  module XMLSecurity
    class SignedDocument < REXML::Document
      ValidationError = Class.new(StandardError)
      C14N = "http://www.w3.org/2001/10/xml-exc-c14n#"
      DSIG = "http://www.w3.org/2000/09/xmldsig#"

      attr_accessor :signed_element_id

      def initialize(response)
        super(response)
        extract_signed_element_id
      end

      def validate(idp_cert_fingerprint, soft = true, options = {})
        base64_cert = find_base64_cert(options)
        cert_text   = Base64.decode64(base64_cert)
        cert        = OpenSSL::X509::Certificate.new(cert_text)

        # check cert matches registered idp cert
        fingerprint = fingerprint_cert(cert, options)
        sha1_fingerprint = fingerprint_cert_sha1(cert)
        plain_idp_cert_fingerprint = idp_cert_fingerprint.gsub(/[^a-zA-Z0-9]/,"").downcase

        if fingerprint != plain_idp_cert_fingerprint && sha1_fingerprint != plain_idp_cert_fingerprint
          return soft ? false : (raise ValidationError.new("Fingerprint mismatch"))
        end

        validate_doc(base64_cert, soft, options)
      end

      def validate_doc(base64_cert, soft = true, options = {})
        if options[:get_params] && options[:get_params][:Signature]
          validate_doc_params_signature(base64_cert, soft, options[:get_params])
        else
          validate_doc_embedded_signature(base64_cert, soft)
        end
      end

      private

      def signature_algorithm(options)
        if options[:get_params] && options[:get_params][:SigAlg]
          algorithm(options[:get_params][:SigAlg])
        else
          ref_elem = REXML::XPath.first(self, "//ds:Reference", {"ds"=>DSIG})
          algorithm(REXML::XPath.first(ref_elem, "//ds:DigestMethod"))
        end
      end

      def fingerprint_cert(cert, options)
        digest_algorithm = signature_algorithm(options)
        digest_algorithm.hexdigest(cert.to_der)
      end

      def fingerprint_cert_sha1(cert)
        OpenSSL::Digest::SHA1.hexdigest(cert.to_der)
      end

      def find_base64_cert(options)
        cert_element = REXML::XPath.first(self, "//ds:X509Certificate", { "ds"=>DSIG })
        if cert_element
          base64_cert = cert_element.text
        elsif options[:cert]
          if options[:cert].is_a?(String)
            base64_cert = options[:cert]
          elsif options[:cert].is_a?(OpenSSL::X509::Certificate)
            base64_cert = Base64.encode64(options[:cert].to_pem)
          else
            raise ValidationError.new("options[:cert] must be Base64-encoded String or OpenSSL::X509::Certificate")
          end
        else
          raise ValidationError.new("Certificate element missing in response (ds:X509Certificate) and not provided in options[:cert]")
        end
      end

      def request?
        root.name != 'Response'
      end

      # matches RubySaml::Utils
      def build_query(params)
        type, data, relay_state, sig_alg = [:type, :data, :relay_state, :sig_alg].map { |k| params[k]}

        url_string = "#{type}=#{CGI.escape(data)}"
        url_string << "&RelayState=#{CGI.escape(relay_state)}" if relay_state
        url_string << "&SigAlg=#{CGI.escape(sig_alg)}"
      end

      def validate_doc_params_signature(base64_cert, soft = true, params)
        document_type = request? ? :SAMLRequest : :SAMLResponse
        canon_string = build_query(
          type: document_type,
          data: params[document_type.to_sym],
          relay_state: params[:RelayState],
          sig_alg: params[:SigAlg]
        )
        verify_signature(base64_cert, params[:SigAlg], Base64.decode64(params[:Signature]), canon_string, soft)
      end

      def validate_doc_embedded_signature(base64_cert, soft = true)
        # check for inclusive namespaces
        inclusive_namespaces = extract_inclusive_namespaces

        document = Nokogiri.parse(self.to_s)

        # create a working copy so we don't modify the original
        @working_copy ||= REXML::Document.new(self.to_s).root

        # store and remove signature node
        @sig_element ||= begin
                           element = REXML::XPath.first(@working_copy, "//ds:Signature", {"ds"=>DSIG})
                           element.remove
                         end


        # verify signature
        signed_info_element     = REXML::XPath.first(@sig_element, "//ds:SignedInfo", {"ds"=>DSIG})
        noko_sig_element = document.at_xpath('//ds:Signature', 'ds' => DSIG)
        noko_signed_info_element = noko_sig_element.at_xpath('./ds:SignedInfo', 'ds' => DSIG)
        canon_algorithm = canon_algorithm REXML::XPath.first(@sig_element, '//ds:CanonicalizationMethod', 'ds' => DSIG)
        canon_string = noko_signed_info_element.canonicalize(canon_algorithm)
        noko_sig_element.remove

        # check digests
        REXML::XPath.each(@sig_element, "//ds:Reference", {"ds"=>DSIG}) do |ref|
          uri                           = ref.attributes.get_attribute("URI").value

          hashed_element                = document.at_xpath("//*[@ID='#{uri[1..-1]}']")
          canon_algorithm               = canon_algorithm REXML::XPath.first(ref, '//ds:CanonicalizationMethod', 'ds' => DSIG)
          canon_hashed_element          = hashed_element.canonicalize(canon_algorithm, inclusive_namespaces)

          digest_algorithm              = algorithm(REXML::XPath.first(ref, "//ds:DigestMethod"))

          hash                          = digest_algorithm.digest(canon_hashed_element)
          digest_value                  = Base64.decode64(REXML::XPath.first(ref, "//ds:DigestValue", {"ds"=>DSIG}).text)

          unless digests_match?(hash, digest_value)
            return soft ? false : (raise ValidationError.new("Digest mismatch"))
          end
        end

        base64_signature        = REXML::XPath.first(@sig_element, "//ds:SignatureValue", {"ds"=>DSIG}).text
        signature               = Base64.decode64(base64_signature)
        sig_alg                 = REXML::XPath.first(signed_info_element, "//ds:SignatureMethod", {"ds"=>DSIG})

        verify_signature(base64_cert, sig_alg, signature, canon_string, soft)
      end

      def verify_signature(base64_cert, sig_alg, signature, canon_string, soft)
        cert_text           = Base64.decode64(base64_cert)
        cert                = OpenSSL::X509::Certificate.new(cert_text)
        signature_algorithm = algorithm(sig_alg)

        unless cert.public_key.verify(signature_algorithm.new, signature, canon_string)
          return soft ? false : (raise ValidationError.new("Key validation error"))
        end

        return true
      end

      def digests_match?(hash, digest_value)
        hash == digest_value
      end

      def extract_signed_element_id
        reference_element       = REXML::XPath.first(self, "//ds:Signature/ds:SignedInfo/ds:Reference", {"ds"=>DSIG})
        self.signed_element_id  = reference_element.attribute("URI").value[1..-1] unless reference_element.nil?
      end

      def canon_algorithm(element)
        algorithm = element.attribute('Algorithm').value if element
        case algorithm
        when "http://www.w3.org/2001/10/xml-exc-c14n#"         then Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0
        when "http://www.w3.org/TR/2001/REC-xml-c14n-20010315" then Nokogiri::XML::XML_C14N_1_0
        when "http://www.w3.org/2006/12/xml-c14n11"            then Nokogiri::XML::XML_C14N_1_1
        else                                                        Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0
        end
      end

      def algorithm(element)
        algorithm = element
        if algorithm.is_a?(REXML::Element)
          algorithm = element.attribute("Algorithm").value
        end
        algorithm = algorithm && algorithm =~ /(rsa-)?sha(.*?)$/i && $2.to_i
        case algorithm
        when 256 then OpenSSL::Digest::SHA256
        when 384 then OpenSSL::Digest::SHA384
        when 512 then OpenSSL::Digest::SHA512
        else
          OpenSSL::Digest::SHA1
        end
      end

      def extract_inclusive_namespaces
        if element = REXML::XPath.first(self, "//ec:InclusiveNamespaces", { "ec" => C14N })
          prefix_list = element.attributes.get_attribute("PrefixList").value
          prefix_list.split(" ")
        else
          []
        end
      end
    end
  end
end
