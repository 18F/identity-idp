require 'saml_idp/xml_security'
require 'saml_idp/service_provider'
module SamlIdp
  class Request
    IAL_PREFIX = %r{^http://idmanagement.gov/ns/assurance/ial}.freeze
    LOA_PREFIX = %r{^http://idmanagement.gov/ns/assurance/loa}.freeze
    AAL_PREFIX = %r{^http://idmanagement.gov/ns/assurance/aal|urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo}.freeze

    def self.from_deflated_request(raw, options = {})
      if raw
        log "#{'~' * 20} RAW Request #{'~' * 20}\n#{raw}\n#{'~' * 18} Done RAW Request #{'~' * 17}\n"
        decoded = Base64.decode64(raw.gsub(/\\r/, '').gsub(/\\n/, ''))
        log "#{'~' * 20} Decoded Request #{'~' * 20}\n#{decoded}\n#{'~' * 18} Done Decoded Request #{'~' * 17}\n"
        zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
        begin
          inflated = zstream.inflate(decoded).tap do
            zstream.finish
            zstream.close
          end
        rescue Zlib::BufError, Zlib::DataError # not compressed
          inflated = decoded
        end
      else
        inflated = ""
      end
      new(inflated, options)
    end

    def self.log(msg, level: :debug)
      if Rails && Rails.logger
        Rails.logger.send(level, msg)
      else
        puts msg
      end
    end


    attr_accessor :raw_xml, :options

    delegate :config, to: :SamlIdp
    private :config
    delegate :xpath, to: :document
    private :xpath

    def initialize(raw_xml = "", options = {})
      self.options = options
      self.raw_xml = raw_xml
    end

    def logout_request?
      logout_request.nil? ? false : true
    end

    def authn_request?
      authn_request.nil? ? false : true
    end

    def request_id
      request["ID"]
    end

    def request
      if authn_request?
        authn_request
      elsif logout_request?
        logout_request
      end
    end

    def force_authn?
      return nil unless authn_request?

      request["ForceAuthn"] == 'true'
    end

    def requested_authn_context
      return authn_context_node.content if authn_request? && authn_context_node
    end

    def requested_authn_context_comparison
      if authn_request? && requested_authn_context_node
        requested_authn_context_node["Comparison"]
      end
    end

    def requested_authn_contexts
      if authn_request? && authn_context_nodes.length > 0
        authn_context_nodes.map(&:content)
      else
        []
      end
    end

    def requested_ial_authn_context
      requested_authn_contexts.select do |classref|
        IAL_PREFIX.match?(classref) || LOA_PREFIX.match?(classref)
      end.first
    end

    def requested_aal_authn_context
      requested_authn_contexts.select do |classref|
        AAL_PREFIX.match?(classref)
      end.first
    end

    def acs_url
      service_provider.acs_url ||
        authn_request["AssertionConsumerServiceURL"].to_s
    end

    def logout_url
      service_provider.assertion_consumer_logout_service_url
    end

    def response_url
      if authn_request?
        acs_url
      elsif logout_request?
        logout_url
      end
    end

    def log(msg)
      if Rails && Rails.logger
        Rails.logger.info msg
      else
        puts msg
      end
    end

    def valid?
      log "Checking validity..."

      unless service_provider?
        log "Unable to find service provider for issuer #{issuer}"
        return false
      end

      unless (authn_request? ^ logout_request?)
        log "One and only one of authnrequest and logout request is required. authnrequest: #{authn_request?} logout_request: #{logout_request?} "
        return false
      end

      unless valid_signature?
        log "Signature is invalid in #{raw_xml}"
        return false
      end

      if response_url.nil?
        log "Unable to find response url for #{issuer}: #{raw_xml}"
        return false
      end

      return true
    end

    def signed?
      document.signed? || !!self.options[:get_params]&.key?(:Signature)
    end

    def valid_signature?
      # Force signatures for logout requests because there is no other
      # protection against a cross-site DoS.
      service_provider.valid_signature?(document, logout_request?, self.options)
    end

    def service_provider?
      service_provider && service_provider.valid?
    end

    def service_provider
      return unless issuer.present?
      @_service_provider ||= ServiceProvider.new((service_provider_finder[issuer] || {}).merge(identifier: issuer))
    end

    def issuer
      @_issuer ||= xpath("//saml:Issuer", saml: assertion).first.try(:content)
      @_issuer if @_issuer.present?
    end

    def name_id
      @_name_id ||= xpath("//saml:NameID", saml: assertion).first.try(:content)
    end

    def name_id_format
      return name_id_format_node.content if authn_request? && name_id_format_node
      nil
    end

    def session_index
      @_session_index ||= xpath("//samlp:SessionIndex", samlp: samlp).first.try(:content)
    end

    def document
      @_document ||= Saml::XML::Document.parse(raw_xml)
    end
    private :document

    def name_id_format_node
      return @_name_id_format_node if defined?(@_name_id_format_node)
      @_name_id_format_node ||= xpath('//samlp:AuthnRequest/samlp:NameIDPolicy/@Format',
                                      samlp: samlp,
                                      saml: assertion).first
    end
    private :name_id_format_node

    def requested_authn_context_node
      @_authn_context_node ||= xpath("//samlp:AuthnRequest/samlp:RequestedAuthnContext",
        samlp: samlp,
        saml: assertion).first
    end
    private :requested_authn_context_node

    def authn_context_node
      @_authn_context_node ||= xpath("//samlp:AuthnRequest/samlp:RequestedAuthnContext/saml:AuthnContextClassRef",
        samlp: samlp,
        saml: assertion).first
    end
    private :authn_context_node

    def authn_context_nodes
      @_authn_context_nodes ||= xpath("//samlp:AuthnRequest/samlp:RequestedAuthnContext/saml:AuthnContextClassRef",
        samlp: samlp,
        saml: assertion)
    end
    private :authn_context_nodes

    def authn_request
      @_authn_request ||= xpath("//samlp:AuthnRequest", samlp: samlp).first
    end
    private :authn_request

    def logout_request
      @_logout_request ||= xpath("//samlp:LogoutRequest", samlp: samlp).first
    end
    private :logout_request

    def samlp
      Saml::XML::Namespaces::PROTOCOL
    end
    private :samlp

    def assertion
      Saml::XML::Namespaces::ASSERTION
    end
    private :assertion

    def signature_namespace
      Saml::XML::Namespaces::SIGNATURE
    end
    private :signature_namespace

    def service_provider_finder
      config.service_provider.finder
    end
    private :service_provider_finder
  end
end
