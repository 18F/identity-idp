class OpenidConnectAttributeScoper
  VALID_SCOPES = %w(
    address
    email
    openid
    phone
    profile
    social_security_number
  ).freeze

  ATTRIBUTE_SCOPE_MAP = {
    email: 'email',
    email_verified: 'email',
    address: 'address',
    phone: 'phone',
    phone_verified: 'phone',
    given_name: 'profile',
    family_name: 'profile',
    birthdate: 'profile',
    social_security_number: 'social_security_number',
  }.with_indifferent_access.freeze

  SCOPE_ATTRIBUTE_MAP = ATTRIBUTE_SCOPE_MAP.group_by(&:last).map do |scope, attribute_scope|
    [scope, attribute_scope.map(&:first).reject { |str| str =~ /_verified$/ }]
  end.to_h.with_indifferent_access.freeze

  CLAIMS = ATTRIBUTE_SCOPE_MAP.keys

  attr_reader :scopes

  def initialize(scope)
    @scopes = parse_scope(scope)
  end

  def filter(user_info)
    user_info.select do |key, _v|
      !ATTRIBUTE_SCOPE_MAP.key?(key) || scopes.include?(ATTRIBUTE_SCOPE_MAP[key])
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
