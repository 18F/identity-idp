FactoryBot.define do
  factory :user_consent_sts do
    user
    target_app { "urn:gov:gsa:openidconnect:sp:broker:#{SecureRandom.hex(4)}" }
  end
end
