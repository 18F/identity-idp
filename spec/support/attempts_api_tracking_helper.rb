module AttemptsApiTrackingHelper
  class AttemptsApiEventDecryptor
    def self.public_key
      private_key.public_key
    end

    def self.private_key
      @private_key ||= OpenSSL::PKey::RSA.new(4096)
    end

    def decrypted_events_from_store(timestamp:)
      jwes = AttemptsApi::RedisClient.new.read_events(timestamp: timestamp)
      jwes.transform_values do |jwe|
        AttemptsApi::AttemptEvent.from_jwe(jwe, self.class.private_key)
      end
    end
  end

  def attempts_api_tracked_events(timestamp:)
    AttemptsApiEventDecryptor.new.decrypted_events_from_store(timestamp: timestamp).values
  end

  def stub_attempts_tracker
    attempts_api_tracker = FakeAttemptsTracker.new

    if respond_to?(:controller)
      allow(controller).to receive(:attempts_api_tracker).and_return(attempts_api_tracker)
    else
      allow(self).to receive(:attempts_api_tracker).and_return(attempts_api_tracker)
    end

    @attempts_api_tracker = attempts_api_tracker
  end
end
