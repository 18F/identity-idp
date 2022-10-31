class IrsAttemptsEventsBatchJob < ApplicationJob
  queue_as :default

  def perform(subject_timestamp = Time.zone.now - 1.hour)
    return nil unless IdentityConfig.store.irs_attempt_api_enabled

    puts "#################### Performing IrsAttemptsEventBatchJob at formatted timestamp: #{subject_timestamp}"

    # THe array of encrypted events
    events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: subject_timestamp)

    event_values = events.values.join("\r\n")

    # Run events through envelope_encryptor - returns
    # Result.new(
    #    filename: filename,
    #    iv: iv,
    #    encrypted_key: encrypted_key,
    #    encrypted_data: encrypted_data,
    #  )
   
    decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
    pub_key = OpenSSL::PKey::RSA.new(decoded_key_der)

    result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
      data: event_values, timestamp: subject_timestamp, public_key: pub_key,
    )
    
    # write this a temp file until S3
    begin
      dir_path = "./attempts_api_output"
      Dir.mkdir(dir_path) unless File.exists?(dir_path)

      file = File.open("#{dir_path}/#{result.filename}", 'wb')
      file.write(result.encrypted_data) 
    rescue IOError => e
      puts e
    ensure
      file.close unless file.nil?
    end
    puts "Wrote to file: #{file.path}"


    # REMOVE THE FOLLOWING BEFORE MERGING 

    #file = File.open("#{dir_path}/#{result.filename}", 'rb')
    
    #private_key_path = 'keys/attempts_api_private_key.key'
    #private_key = OpenSSL::PKey::RSA.new(File.read(private_key_path))
    #final_key = private_key.private_decrypt(result.encrypted_key)

    #puts "@@@@@@@@@@@@@@@@@@@@@@@@@@ DECRYPTING THE FILE @@@@@@@@@@@@@@@@@@@@@@"
    #puts IrsAttemptsApi::EnvelopeEncryptor.decrypt(encrypted_data: file.read, key: final_key, iv: result.iv)

    
    # Write the file to S3 instead of whatever dir_path winds up being

  end
end