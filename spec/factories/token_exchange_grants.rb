FactoryBot.define do
  factory :token_exchange_grant do
    user { association :user, :fully_registered }
    transient do
      service_provider { association :service_provider, :delegation_service_provider }
    end
    service_provider_issuer { service_provider.issuer }
    application { association :service_provider, :delegation_application }
    source { 'consent_screen' }
    consented_at { Time.zone.now }
    remember_until { 1.year.from_now }
    agency_content_version { application.agency&.consent_content_version || 1 }
    application_content_version { application.consent_content_version }
    sp_content_version { service_provider.sp_content_version }
    proofed_in_session { false }

    trait :single_authorization do
      remember_until { nil }
      rails_session_id { SecureRandom.uuid }
    end

    trait :from_account_page do
      source { 'account_page' }
    end

    trait :revoked do
      revoked_at { Time.zone.now }
      revocation_reason { 'user_revoked' }
    end
  end
end
