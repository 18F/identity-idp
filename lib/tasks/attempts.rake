require 'base16'

namespace :attempts do
  desc 'Retrieve events via the API'
  task fetch_events: :environment do
    auth_token = IdentityConfig.store.irs_attempt_api_auth_tokens.sample
    puts 'There are no configured irs_attempt_api_auth_tokens' if auth_token.nil?
    private_key_path = 'keys/attempts_api_private_key.key'

    conn = Faraday.new(url: 'http://localhost:3000')
    body = "timestamp=#{Time.zone.now.iso8601}"

    resp = conn.post('/api/irs_attempts_api/security_events', body) do |req|
      req.headers['Authorization'] =
        "Bearer #{IdentityConfig.store.irs_attempt_api_csp_id} #{auth_token}"
    end

    iv = Base64.strict_decode64(resp.headers['x-payload-iv'])
    encrypted_key = Base64.strict_decode64(resp.headers['x-payload-key'])
    private_key = OpenSSL::PKey::RSA.new(File.read(private_key_path))
    key = private_key.private_decrypt(encrypted_key)
    decrypted = IrsAttemptsApi::EnvelopeEncryptor.decrypt(
      encrypted_data: resp.body, key: key, iv: iv,
    )

    events = decrypted.split("\r\n")
    puts "Found #{events.count} events"

    if File.exist?(private_key_path)
      puts events.any? ? 'Decrypted events:' : 'No events returned.'

      events.each do |jwe|
        begin
          pp JSON.parse(JWE.decrypt(jwe, private_key))
        rescue => e
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
    auth_token = IdentityConfig.store.irs_attempt_api_auth_tokens.sample
    puts 'There are no configured irs_attempt_api_auth_tokens' if auth_token.nil?
    private_key_path = 'keys/attempts_api_private_key.key'

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
      puts '❌ FAILED: Run rake attempts:enable_for_sinatra'
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
  
  desc 'Enable irs_attempts_api_enabled for Sinatra SP'
  task enable_for_sinatra: :environment do
    sp = ServiceProvider.find_by(friendly_name: 'Example Sinatra App')
    sp.update(irs_attempts_api_enabled: true)
  end

  desc 'Clear all events from Redis'
  task purge_events: :environment do
    IrsAttemptsApi::RedisClient.clear_attempts!
  end

  desc 'Generate a simple gzipped file'
  task write_event: :environment do
    events = [_generate_event, _generate_event]

    decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
    pub_key = OpenSSL::PKey::RSA.new(decoded_key_der)

    result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
      data: events.join("\r\n"),
      timestamp: Time.zone.now,
      public_key: pub_key,
    )

    file = File.open(result.filename, 'wb')
    file.write(result.encrypted_data)
    puts "IV: #{Base64.encode64(result.iv)}"
    puts "Encrypted key: #{Base64.encode64(result.encrypted_key).delete("\n")}"
  end

  task decrypt_file: :environment do
    iv = Base64.strict_decode64(ENV['IRS_IV'])
    encrypted_key = Base64.strict_decode64(ENV['IRS_KEY'])
    puts "File is #{ARGV[1]}"
    file_contents = File.read("./#{ARGV[1]}")

    puts "IV: #{iv.size}"
    puts "Key: #{encrypted_key.size}"
    puts "File contents: #{file_contents}"

    private_key_path = 'keys/attempts_api_private_key.key'
    private_key = OpenSSL::PKey::RSA.new(File.read(private_key_path))
    key = private_key.private_decrypt(encrypted_key)
    decrypted = IrsAttemptsApi::EnvelopeEncryptor.decrypt(
      encrypted_data: file_contents, key: key, iv: iv,
    )

    puts decrypted
  end

  task decode16: :environment do |_task, args|
    file = File.open(ARGV[1], 'rb')
    decoded = Base16.decode16(file.read)
  end

  # Don't commit this
  def _generate_event
    event = IrsAttemptsApi::AttemptEvent.new(
      event_type: 'test',
      session_id: SecureRandom.uuid,
      occurred_at: Time.zone.now,
      event_metadata: { foo: 'bar' },
      jti: SecureRandom.uuid,
      iat: Time.zone.now.to_i,
    ).to_jwe
  end
end
