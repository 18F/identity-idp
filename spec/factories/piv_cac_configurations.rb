FactoryBot.define do
  Faker::Config.locale = :en

  factory :piv_cac_configuration do
    name do
      Faker::Lorem.unique.words.join(' ')[0, UserSuppliedNameAttributes::MAX_NAME_LENGTH].strip
    end
    x509_dn_uuid { Random.uuid }
    user
  end
end
