FactoryBot.define do
  Faker::Config.locale = :en

  factory :service_provider_request do
    issuer { 'urn:gov:gsa:openidconnect:sp:sinatra' }
    loa { 'http://idmanagement.gov/ns/assurance/loa/1' }
    url { 'http://localhost:3000/openid_connect/authorize' }
    uuid { SecureRandom.uuid }
  end
end
