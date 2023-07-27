FactoryBot.define do
  factory :suspended_email do
    digested_base_email { 'test_digest' }
    association :email_address
  end
end
