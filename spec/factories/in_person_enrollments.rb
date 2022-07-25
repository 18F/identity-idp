FactoryBot.define do
  factory :in_person_enrollment do
    user { association :user, :signed_up }
    profile { association :profile, user: user }

    trait :pending do
      after :build do |enrollment|
        enrollment.status = :pending
        enrollment.enrollment_code = Faker::Number.number(digits: 16)
      end
    end
  end
end
