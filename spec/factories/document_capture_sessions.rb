FactoryBot.define do
  factory :document_capture_session do
    uuid { SecureRandom.uuid }
    user { association :user, :fully_registered }
  end

  trait :socure do
    socure_docv_transaction_token { SecureRandom.uuid }
    socure_docv_capture_app_url { 'https://capture-app.test' }
  end
end
