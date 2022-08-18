namespace :attempts do
  auth_token = IdentityConfig.store.irs_attempt_api_auth_tokens.sample
  puts 'There are no configured irs_attempt_api_auth_tokens' if auth_token.nil?
  private_key_path = 'keys/attempts_api_private_key.key'

  desc 'Retrieve events via the API'
  task fetch_events: :environment do
    conn = Faraday.new(url: 'http://localhost:3000')
    body = "timestamp=#{Time.zone.now.iso8601}"

    resp = conn.post('/api/irs_attempts_api/security_events', body) do |req|
      req.headers['Authorization'] =
        "Bearer #{IdentityConfig.store.irs_attempt_api_csp_id} #{auth_token}"
    end
    encrypted_data = Base64.strict_decode64(resp.body)
    iv = Base64.strict_decode64(resp.headers['x-payload-iv'])
    encrypted_key = Base64.strict_decode64(resp.headers['x-payload-key'])
    private_key = OpenSSL::PKey::RSA.new(File.read(private_key_path))
    key = private_key.private_decrypt(encrypted_key)
    decrypted = IrsAttemptsApi::EnvelopeEncryptor.decrypt(encrypted_data: encrypted_data, key: key, iv: iv)
    deflated_decrypted = Zlib.gunzip(decrypted)
    events = JSON.parse(deflated_decrypted)

    if File.exist?(private_key_path)
      puts events.any? ? 'Decrypted events:' : 'No events returned.'

      events.each do |_jti, event|
        begin
          pp JSON.parse(JWE.decrypt(event, private_key))
        rescue
          puts 'Failed to parse/decrypt event!'
        end
        puts "\n"
      end
    else
      puts "No decryption key in #{private_key_path}; cannot decrypt events."
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

    if IdentityConfig.store.irs_attempt_api_auth_tokens.include?(auth_token)
      puts "✅ #{auth_token} set as auth token"
    else
      failed = true
      puts "❌ FAILED: set irs_attempt_api_auth_tokens='#{auth_token}' in application.yml.default"
    end

    if File.exist?(private_key_path)
      puts "✅ '#{private_key_path}' exists for decrypting events"
    else
      puts "❌ FAILED: Private key '#{private_key_path}' does not exist; unable to decrypt events"
    end

    puts 'Remember to restart Rails after updating application.yml.default!' if failed
  end

  desc 'Clear all events from Redis'
  task purge_events: :environment do
    IrsAttemptsApi::RedisClient.clear_attempts!
  end
end
