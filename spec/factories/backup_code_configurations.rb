FactoryBot.define do
  factory :backup_code_configuration do
    code { SecureRandom.hex(6) }
    user
  end
end
