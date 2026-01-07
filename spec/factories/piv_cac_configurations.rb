FactoryBot.define do
  include UserSuppliedNameAttributes
  Faker::Config.locale = :en

  factory :piv_cac_configuration do
    name { Faker::Lorem.unique.words.join(' ')[0, UserSuppliedNameAttributes::MAX_NAME_LENGTH] }
    x509_dn_uuid { Random.uuid }
    user
  end
end
