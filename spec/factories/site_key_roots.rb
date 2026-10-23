FactoryBot.define do
  factory :site_key_root do
    user
    encrypted_root { 'encrypted' }
    public_key { SiteKeys::RootKeyPair.generate.public_jwk }
  end
end
