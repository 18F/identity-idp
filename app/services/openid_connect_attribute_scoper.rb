class OpenidConnectAttributeScoper
  VALID_SCOPES = %w[
    address
    email
    openid
    phone
    profile
    profile:birthdate
    profile:name
    social_security_number
    x509
    x509:subject
    x509:presented
  ].freeze

  ATTRIBUTE_SCOPES_MAP = {
    email: %w[email],
    email_verified: %w[email],
    address: %w[address],
    phone: %w[phone],
    phone_verified: %w[phone],
    given_name: %w[profile profile:name],
    family_name: %w[profile profile:name],
    birthdate: %w[profile profile:birthdate],
    social_security_number: %w[social_security_number],
    x509_subject: %w[x509 x509:subject],
    x509_presented: %w[x509 x509:presented],
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

  CLAIMS = ATTRIBUTE_SCOPES_MAP.keys

  attr_reader :scopes

  def initialize(scope)
    @scopes = parse_scope(scope)
  end

  def filter(user_info)
    user_info.select do |key, _v|
      !ATTRIBUTE_SCOPES_MAP.key?(key) || (scopes & ATTRIBUTE_SCOPES_MAP[key]).present?
    end
  end

  def requested_attributes
    scopes.map { |scope| SCOPE_ATTRIBUTE_MAP[scope] }.flatten.compact
  end

  private

  def parse_scope(scope)
    return [] if scope.blank?
    scope.split(' ').flatten.compact & VALID_SCOPES
  end
end
