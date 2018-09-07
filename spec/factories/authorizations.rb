FactoryBot.define do
  factory :authorization do
    provider { 'saml' }
    uid { '1234' }
    user_id { 1 }
  end
end
