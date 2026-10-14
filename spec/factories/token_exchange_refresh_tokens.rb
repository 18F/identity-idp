FactoryBot.define do
  # A refresh token row. Pass `plaintext:` to control the token string a spec presents; by
  # default a fresh one is generated and exposed through the transient attribute.
  factory :token_exchange_refresh_token do
    transient do
      plaintext { TokenExchangeRefreshToken.generate_token }
    end

    token_exchange_token { association :token_exchange_token }
    grant { token_exchange_token.grant }
    family_id { token_exchange_token.refresh_family_id }
    resource_server { token_exchange_token.resource_server }
    service_provider { token_exchange_token.service_provider }
    user { token_exchange_token.user }
    scope { token_exchange_token.scope }
    dpop_jkt { token_exchange_token.dpop_jkt }
    token_digest { TokenExchangeRefreshToken.digest(plaintext) }
    expires_at { 12.hours.from_now }

    trait :rotated do
      used_at { 1.minute.ago }
      rotated_at { 1.minute.ago }
    end

    trait :revoked do
      revoked_at { Time.zone.now }
      revocation_reason { 'user_revoked' }
    end
  end
end
