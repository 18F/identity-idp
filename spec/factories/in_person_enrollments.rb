FactoryBot.define do
  factory :in_person_enrollment do
    user { association :user, :signed_up }
    profile { association :profile, user: user }
    unique_id { Faker::Number.hexadecimal(digits: 18) }

    trait :establishing do
      after :build do |enrollment|
        enrollment.status = :establishing
      end
    end

    trait :pending do
      after :build do |enrollment|
        enrollment.status = :pending
        enrollment.enrollment_code = Faker::Number.number(digits: 16)
      end
    end
  end
end
