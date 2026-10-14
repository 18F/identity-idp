# frozen_string_literal: true

module SamlIdpExtensions
  # Three small generalizations of `SamlIdp::AssertionBuilder`, prepended to the gem class from
  # `config/initializers/saml_idp.rb` so they can be carried here until the gem carries them.
  # All three are no-ops for the browser sign-in flow, which always answers an AuthnRequest and
  # takes the defaults, so its assertions are byte-identical to the gem's own output
  # (spec/lib/saml_idp_extensions/assertion_builder_spec.rb compares the two).
  #
  # 1. `SubjectConfirmationData/@InResponseTo` is emitted only when there is a request ID. The gem
  #    always emits it, which for an assertion issued without an AuthnRequest (a delegated
  #    assertion returned to a server) would be an empty `InResponseTo=""`; SAML 2.0 Core §2.4.1.2
  #    defines the attribute as optional and relying parties reject an empty value.
  # 2. The bearer subject-confirmation window (`SubjectConfirmationData/@NotOnOrAfter`) can be set
  #    through a `subject_confirmation_expiry:` keyword instead of being fixed at three minutes,
  #    which suits a browser POST but not a token a server holds and presents.
  # 3. The instant the assertion is issued at can be pinned through `issue_instant:`, so
  #    `IssueInstant` and both `NotOnOrAfter` values agree to the second with the record the
  #    issuer keeps of the assertion's lifetime.
  #
  # `fresh` below is the gem's method with only the subject-confirmation line changed; keep it in
  # step with the gem when the pin moves.
  module AssertionBuilder
    DEFAULT_SUBJECT_CONFIRMATION_EXPIRY = 3 * 60

    attr_writer :subject_confirmation_expiry

    def initialize(
      *args, subject_confirmation_expiry: DEFAULT_SUBJECT_CONFIRMATION_EXPIRY, issue_instant: nil
    )
      super(*args)
      self.subject_confirmation_expiry = subject_confirmation_expiry
      @now = issue_instant&.utc
    end

    def subject_confirmation_expiry
      @subject_confirmation_expiry || DEFAULT_SUBJECT_CONFIRMATION_EXPIRY
    end

    # Formatted as in the gem so the two can be diffed directly.
    # rubocop:disable Layout/LineLength, Style/TrailingCommaInArguments, Metrics/BlockLength
    # rubocop:disable Performance/Detect, Performance/StringInclude
    def fresh
      builder = Builder::XmlMarkup.new
      builder.Assertion xmlns: Saml::XML::Namespaces::ASSERTION,
                        ID: reference_string,
                        IssueInstant: now_iso,
                        Version: '2.0' do |assertion|
        assertion.Issuer issuer_uri
        sign assertion
        assertion.Subject do |subject|
          subject.NameID name_id, Format: sp_name_id_format.fetch(:name)
          subject.SubjectConfirmation Method: Saml::XML::Namespaces::Methods::BEARER do |confirmation|
            confirmation.SubjectConfirmationData '', subject_confirmation_data_attributes
          end
        end
        assertion.Conditions NotBefore: not_before,
                             NotOnOrAfter: not_on_or_after_condition do |conditions|
          conditions.AudienceRestriction do |restriction|
            restriction.Audience audience_uri
          end
        end
        if asserted_attributes
          assertion.AttributeStatement do |attr_statement|
            asserted_attributes.each do |friendly_name, attrs|
              attrs = (attrs || {}).with_indifferent_access
              attr_statement.Attribute Name: attrs[:name] || friendly_name,
                                       NameFormat: attrs[:name_format] || Saml::XML::Namespaces::Formats::Attr::URI,
                                       FriendlyName: friendly_name.to_s do |attr|
                values = get_values_for friendly_name, attrs[:getter]
                values.each do |val|
                  attr.AttributeValue val.to_s
                end
              end
            end
          end
        end
        assertion.AuthnStatement AuthnInstant: iso { authn_instant.utc },
                                 SessionIndex: reference_string do |statement|
          statement.AuthnContext do |context|
            case authn_context_classref
            when Array
              context.AuthnContextClassRef(
                authn_context_classref.select { |classref| %r{/ial/}.match? classref }.first
              )
            else
              context.AuthnContextClassRef authn_context_classref
            end
          end
        end
      end
    end
    # rubocop:enable Layout/LineLength, Style/TrailingCommaInArguments, Metrics/BlockLength
    # rubocop:enable Performance/Detect, Performance/StringInclude
    # The gem aliases `raw` to its own `fresh`, which pins `raw` to the original body; re-alias so
    # signing and encryption (which read `raw`) see this version.
    alias_method :raw, :fresh
    private :fresh

    private

    # Attribute order is the gem's (InResponseTo, NotOnOrAfter, Recipient) so output with a
    # request ID is unchanged; the first is dropped when there is no request to answer.
    def subject_confirmation_data_attributes
      { InResponseTo: saml_request_id }.compact.merge(
        NotOnOrAfter: not_on_or_after_subject,
        Recipient: saml_acs_url,
      )
    end

    def not_on_or_after_subject
      iso { now + subject_confirmation_expiry }
    end
  end
end
