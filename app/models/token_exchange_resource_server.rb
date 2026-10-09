# frozen_string_literal: true

# One API URL of an application registered for delegated access.
#
# The `identifier` is the RFC 8707 `resource` value a service provider names at exchange, the
# audience of the delegated token, and the API's client identifier when it authenticates to
# Login.gov to verify a token. Login.gov, not the service provider, defines this list; a service
# provider can only name URLs that are registered under an application the user approved.
class TokenExchangeResourceServer < ApplicationRecord
  TOKEN_FORMATS = %w[oauth saml2].freeze

  # The owning application: a service provider record with `delegation_application: true`.
  belongs_to :service_provider
  # Optional override of which record's Attempts API credentials receive fraud-signal events.
  belongs_to :attempts_service_provider, class_name: 'ServiceProvider', optional: true

  validates :identifier, presence: true, uniqueness: true
  validates :token_format, inclusion: { in: TOKEN_FORMATS }

  scope :active, -> { where(active: true) }

  # A URL is usable only while it, its application and the application's agency are active.
  # This is the kill switch: flipping any of the three stops exchange, refresh and verification
  # for the URL immediately.
  def usable?
    active? && service_provider&.delegation_application? && service_provider.active?
  end

  def saml?
    token_format == 'saml2'
  end

  # The service provider record whose Attempts API credentials receive fraud-signal events for
  # delegated sessions at this URL; defaults to the owning application.
  def attempts_recipient
    attempts_service_provider || service_provider
  end

  # Issuer whose partner agreement is billed for delegated use of this URL; defaults to the
  # owning application's issuer. It must be an issuer wired into an agreement or the billing row
  # is recorded but never invoiced (see #billing_issuer_has_agreement?).
  def billing_issuer_value
    billing_issuer.presence || service_provider.issuer
  end

  # Whether the billing issuer resolves to a partner agreement. Onboarding warns when it does not,
  # because delegated use would then be recorded but never billed.
  def billing_issuer_has_agreement?
    Agreements::Integration.exists?(issuer: billing_issuer_value)
  end

  # Certificates used to verify the API's `private_key_jwt` client assertions, in the same two
  # forms `ServiceProvider#ssl_certs` accepts: a PEM string stored inline, or a name resolved to
  # `certs/sp/<name>.crt`. Inline PEM lets a sandbox register an API without a file on disk.
  # @return [Array<OpenSSL::X509::Certificate>]
  def ssl_certs
    @ssl_certs ||= Array(certs).select(&:present?).map do |cert|
      cert_content = load_cert(cert)
      OpenSSL::X509::Certificate.new(cert_content) if cert_content
    end.compact
  end

  private

  def load_cert(cert)
    if cert.include?('-----BEGIN CERTIFICATE-----')
      cert
    elsif (cert_file = Rails.root.join('certs', 'sp', "#{cert}.crt")) && File.exist?(cert_file)
      File.read(cert_file)
    end
  end
end
