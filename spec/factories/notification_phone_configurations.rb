FactoryBot.define do
  Faker::Config.locale = :en

  factory :notification_phone_configuration do
    phone { '+1 202-555-1212' }
    in_person_enrollment { association :in_person_enrollment }
  end

  trait :notifcation_sent do
    phone { nil }
    notification_sent_at { Time.zone.now }
  end
end
