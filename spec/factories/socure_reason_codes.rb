FactoryBot.define do
  factory :socure_reason_code do
    sequence(:code) { |n| "I#{n}" }
    description { 'Document is valid' }
    group { 'ProductA' }
    added_at { Time.zone.now }

    trait :deactivated do
      deactivated_at { Time.zone.now }
    end

    trait :failure do
      # failure codes start with `R`
      sequence(:code) { |n| "R#{n}" }
    end
  end
end
