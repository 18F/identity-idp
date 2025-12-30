FactoryBot.define do
  Faker::Config.locale = :en

  factory :piv_cac_configuration do
    name { Faker::Lorem.characters(number: 10) }
    x509_dn_uuid { Random.uuid }
    user
  end
end
