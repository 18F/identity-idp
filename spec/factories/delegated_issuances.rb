FactoryBot.define do
  factory :delegated_issuance do
    delegation_id { DelegatedIssuance.generate_delegation_id }
    user
    actor_return_log do
      association(:sp_return_log, user:, issuer: actor_issuer, ial: 2, billable: true)
    end
    target_return_log do
      association(:sp_return_log, user:, issuer: target_issuer, ial: 2, billable: true)
    end
    actor_issuer { 'actor-issuer' }
    target_issuer { 'target-issuer' }
    resource { 'https://api.example.gov/resource' }
    scope { 'openid token_exchange:resource' }
    issued_at { Time.zone.now }
    expires_at { 10.minutes.from_now }
  end
end
