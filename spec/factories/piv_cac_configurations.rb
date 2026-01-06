FactoryBot.define do
  Faker::Config.locale = :en

  factory :piv_cac_configuration do
    name { Faker::Lorem.unique.words.join(' ')[0, 19] }
    x509_dn_uuid { Random.uuid }
    user
  end
end
