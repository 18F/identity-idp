FactoryBot.define do
  factory :in_person_enrollment do
    user { association :user, :signed_up, profiles: [profile] }
    profile { association :profile, user: user }
  end
end
