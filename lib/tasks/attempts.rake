namespace :attempts do
  AUTH_TOKEN = 'abc123'
  PRIVATE_KEY_PATH = 'keys/attempts_api_private_key.key'

  desc 'Retrieve events via the API'
  task fetch_events: :environment do
    conn = Faraday.new(url: 'http://localhost:3000')

    resp = conn.post('/api/irs_attempts_api/security_events') do |req|
      req.headers['Authorization'] = "Bearer #{AUTH_TOKEN}"
    end.body

    events = JSON.parse(resp)

    if File.exist?(PRIVATE_KEY_PATH)
      puts events['sets'].any? ? 'Decrypted events:' : 'No events returned.'

      key = OpenSSL::PKey::RSA.new(File.read(PRIVATE_KEY_PATH))
      events['sets'].each do |event|
        begin
          pp JSON.parse(JWE.decrypt(event[1], key))
        rescue
          puts 'Failed to parse/decrypt event!'
        end
        puts "\n"
      end
    else
      puts 'No decryption key in keys/irs-private-key.key; cannot decrypt events.'
      pp events
    end
  end

  desc 'Confirm your dev setup is configured properly'
  task check_enabled: :environment do
    failed = false

    if IdentityConfig.store.irs_attempt_api_enabled
      puts '✅ Feature flag is enabled'
    else
      failed = true
      puts '❌ FAILED: Set irs_attempt_api_enabled=true in application.yml.default'
    end

    sp = ServiceProvider.find_by(friendly_name: 'Example Sinatra App')
    if sp.irs_attempts_api_enabled
      puts '✅ Sinatra app SP has irs_attempts_api_enabled=true'
    else
      failed = true
      puts "❌ FAILED: Set irs_attempts_api_enabled=true on ServiceProvider.find #{sp.id}"
    end

    if IdentityConfig.store.irs_attempt_api_auth_tokens.include?(AUTH_TOKEN)
      puts "✅ #{AUTH_TOKEN} set as auth token"
    else
      failed = true
      puts "❌ FAILED: set irs_attempt_api_auth_tokens='#{AUTH_TOKEN}' in application.yml.default"
    end

    if File.exist?(PRIVATE_KEY_PATH)
      puts "✅ '#{PRIVATE_KEY_PATH}' exists for decrypting events"
    else
      puts "❌ FAILED: Private key '#{PRIVATE_KEY_PATH}' does not exist; unable to decrypt events"
    end

    puts 'Remember to restart Rails after updating application.yml.default!' if failed
  end

  desc 'Clear all events from Redis'
  task purge_events: :environment do
    IrsAttemptsApi::RedisClient.clear_attempts!
  end
end
