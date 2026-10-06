FactoryBot.define do
  factory :site_key_root do
    user
    encrypted_root { 'encrypted' }
  end
end
