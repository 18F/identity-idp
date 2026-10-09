# frozen_string_literal: true

class OpenidConnectAttributeScoper
  X509_SCOPES = %w[
    x509
    x509:subject
    x509:issuer
    x509:presented
  ].freeze

  IAL2_SCOPES = %w[
    address
    phone
    profile
    profile:name
    profile:birthdate
    social_security_number
    document_images
  ].freeze

  VALID_SCOPES = (%w[
    email
    all_emails
    locale
    openid
    profile:verified_at
  ] + X509_SCOPES + IAL2_SCOPES).freeze

  VALID_IAL1_SCOPES = (%w[
    email
    all_emails
    locale
    openid
    profile:verified_at
  ] + X509_SCOPES).freeze

  ATTRIBUTE_SCOPES_MAP = {
    email: %w[email],
    email_verified: %w[email],
    all_emails: %w[all_emails],
    locale: %w[locale],
    address: %w[address],
    phone: %w[phone],
    phone_verified: %w[phone],
    given_name: %w[profile profile:name],
    family_name: %w[profile profile:name],
    birthdate: %w[profile profile:birthdate],
    verified_at: %w[profile profile:verified_at],
    social_security_number: %w[social_security_number],
    x509_subject: %w[x509 x509:subject],
    x509_presented: %w[x509 x509:presented],
    x509_issuer: %w[x509 x509:issuer],
    document_images: %w[document_images],
    document_metadata: %w[document_images],
  }.with_indifferent_access.freeze

  SCOPE_ATTRIBUTE_MAP = {}.tap do |scope_attribute_map|
    ATTRIBUTE_SCOPES_MAP.each do |attribute, scopes|
      next [] if attribute.match?(/_verified$/)
      scopes.each do |scope|
        scope_attribute_map[scope] ||= []
        scope_attribute_map[scope] << attribute
      end
    end
  end.with_indifferent_access.freeze

  CLAIMS = ATTRIBUTE_SCOPES_MAP.keys.freeze
  UNSCOPED_CLAIMS = %w[auth_time iss sub].freeze

  # Delegation scopes name an agency application the service provider wants to act at for the
  # user: `token_exchange:<delegation_scope_value>`. The values are defined by the application
  # registry, not by this list, so they are kept through parsing and validated against the
  # registry by OpenidConnectAuthorizeForm. They are never attribute scopes: they release no
  # claim and never reach requested_attributes or verified_attributes.
  DELEGATION_SCOPE_PREFIX = ServiceProvider::DELEGATION_SCOPE_PREFIX

  def self.delegation_scope?(value)
    value.to_s.start_with?(DELEGATION_SCOPE_PREFIX)
  end

  attr_reader :scopes

  def initialize(scope)
    @scopes = parse_scope(scope)
  end

  def ial2_scopes_requested?
    (scopes & IAL2_SCOPES).any?
  end

  def x509_scopes_requested?
    (scopes & X509_SCOPES).any?
  end

  def verified_at_requested?
    scopes.include?('profile:verified_at') || scopes.include?('profile')
  end

  def all_emails_requested?
    scopes.include?('all_emails')
  end

  def document_images_requested?
    scopes.include?('document_images')
  end

  def locale_requested?
    scopes.include?('locale')
  end

  def filter(user_info)
    user_info.select do |key, _v|
      !ATTRIBUTE_SCOPES_MAP.key?(key) || (scopes & ATTRIBUTE_SCOPES_MAP[key]).present?
    end
  end

  def requested_attributes
    scopes.map { |scope| SCOPE_ATTRIBUTE_MAP[scope] }.flatten.compact
  end

  # Bare delegation scope values ("housing_records" for "token_exchange:housing_records"), in the
  # order requested.
  def delegation_scope_values
    scopes.select { |value| self.class.delegation_scope?(value) }
      .map { |value| value.delete_prefix(DELEGATION_SCOPE_PREFIX) }
  end

  def delegation_requested?
    delegation_scope_values.any?
  end

  private

  # Attribute scopes are intersected with the fixed list, so an unknown value is silently
  # ignored as it always has been (existing integrations send values that are not scopes).
  # Delegation scopes are kept as given; the authorize form validates them against the registry.
  def parse_scope(scope)
    return [] if scope.blank?
    values = scope.split(' ').flatten.compact
    (values & VALID_SCOPES) + values.select { |value| self.class.delegation_scope?(value) }.uniq
  end
end
