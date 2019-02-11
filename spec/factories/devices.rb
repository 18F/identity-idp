FactoryBot.define do
  factory :device do
    cookie_uuid { SecureRandom.hex(64) }
    user_agent do
      'Google Chrome Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\
(KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'
    end
    last_used_at { Time.zone.now }
    last_ip { '127.0.0.1' }
    user
  end
end
