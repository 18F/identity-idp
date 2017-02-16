class OpenidConnectAttributeScoper
  VALID_SCOPES = %w(
    address
    email
    openid
    phone
    profile
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
  }.with_indifferent_access.freeze

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

  private

  def parse_scope(scope)
    return [] if scope.blank?
    scope.split(' ').compact & VALID_SCOPES
  end
end
