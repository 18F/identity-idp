FactoryBot.define do
  factory :proofing_component do
    association :user, factory: %i[user fully_registered]

    trait :eligible_for_review do
      verified_at { Time.zone.now }
      threatmetrix_review_status { 'review' }
    end
  end
end
