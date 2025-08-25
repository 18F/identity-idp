FactoryBot.define do
  factory :duplicate_profile do
    profile_ids { [] }
    service_provider { OidcAuthHelper::OIDC_FACIAL_MATCH_ISSUER }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
  end
end
