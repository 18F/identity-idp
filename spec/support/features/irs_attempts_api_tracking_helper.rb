module IrsAttemptsApiTrackingHelper
  class IrsAttemptsApiEventDecryptor
    def self.public_key
      private_key.public_key
    end

    def self.private_key
      @private_key ||= OpenSSL::PKey::RSA.new(4096)
    end

    def decrypted_events_from_store(timestamp:)
      jwes = IrsAttemptsApi::RedisClient.new.read_events(timestamp: timestamp)
      jwes.transform_values do |jwe|
        IrsAttemptsApi::AttemptEvent.from_jwe(jwe, self.class.private_key)
      end
    end
  end

  def mock_irs_attempts_api_encryption_key
    encoded_key = Base64.strict_encode64(IrsAttemptsApiEventDecryptor.public_key.to_der)
    allow(IdentityConfig.store).to receive(:irs_attempt_api_public_key).
      and_return(encoded_key)
  end

  def irs_attempts_api_tracked_events(timestamp:)
    IrsAttemptsApiEventDecryptor.new.decrypted_events_from_store(timestamp: timestamp).values
  end

  def stub_attempts_tracker
    irs_attempts_api_tracker = FakeAttemptsTracker.new

    allow(controller).to receive(:irs_attempts_api_tracker).and_return(irs_attempts_api_tracker)

    @irs_attempts_api_tracker = irs_attempts_api_tracker
  end
end
