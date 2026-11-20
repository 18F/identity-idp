FactoryBot.define do
  factory :user_consent_sts do
    user
    target_app { "urn:gov:gsa:openidconnect:sp:target:#{SecureRandom.hex(4)}" }
    actor_app { "urn:gov:gsa:openidconnect:sp:broker:#{SecureRandom.hex(4)}" }
    is_revoked { false }
  end
end
