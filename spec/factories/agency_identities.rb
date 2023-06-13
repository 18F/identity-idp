FactoryBot.define do
  factory :agency_identity do
    association :user, factory: %i[user fully_registered]
    association :agency
    uuid { SecureRandom.uuid }
  end
end
