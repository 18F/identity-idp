FactoryBot.define do
  factory :site_key do
    user
    encrypted_private_key { 'encrypted' }
    public_key { SiteKeys::KeyPair.generate.public_jwk.to_json }
  end
end
