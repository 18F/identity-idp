FactoryBot.define do
  Faker::Config.locale = :en

  factory :piv_cac_configuration do
    name { Faker::Lorem.word }
    x509_dn_uuid { 'helloworld' }
    user
  end
end
