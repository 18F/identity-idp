FactoryBot.define do
  # An issuance record. Pass `plaintext:` to also store the live token in Redis, as the exchange
  # does, so a spec can present the token to an endpoint.
  factory :token_exchange_token do
    transient do
      plaintext { nil }
    end

    # Created even under `build`, so the delegation id the grant assigns on create is available.
    grant { association :token_exchange_grant, strategy: :create }
    resource_server do
      association :token_exchange_resource_server, service_provider: grant.application
    end
    service_provider { grant.service_provider_record }
    user { grant.user }
    delegation_id { grant.delegation_id }
    scope { grant.application.delegation_scope }
    ial { 2 }
    aal { 2 }
    refresh_family_id { SecureRandom.uuid }
    token_type { 'Bearer' }
    token_format { 'oauth' }
    issued_at { Time.zone.now }
    expires_at { 15.minutes.from_now }

    trait :key_bound do
      token_type { 'DPoP' }
      dpop_jkt { Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false) }
    end

    trait :revoked do
      revoked_at { Time.zone.now }
      revocation_reason { 'user_revoked' }
    end

    after(:create) do |token, evaluator|
      next if evaluator.plaintext.blank?

      DelegatedTokenStore.write(
        evaluator.plaintext, token.live_attributes, ttl: token.lifetime_seconds
      )
    end
  end
end
