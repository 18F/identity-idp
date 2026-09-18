FactoryBot.define do
  factory :document_artifact do
    document_capture_session
    image_type { 'front' }
    storage_name { "encrypted_images/#{SecureRandom.uuid}" }
    encryption_key { Base64.strict_encode64(SecureRandom.bytes(32)) }
  end
end
