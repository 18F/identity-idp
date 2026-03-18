# frozen_string_literal: true

module AttemptsApi
  class HistoricalAttempts
    def initialize(idv_session:, user_session:, password:)
      @password = password
      @idv_session = idv_session
      @user_session = user_session
    end

    def record_events
      return unless historical_events_enabled?

      encrypted_events = encrypt_attempt_events_bundle
      encrypted_events_json = JSON.parse(encrypted_events)

      if !existing_user_proofing_event
        new_user_proofing_event = UserProofingEvent.new(
          encrypted_events:,
          profile_id: @profile.id,
          service_providers_sent: [],
          cost: encrypted_events_json['cost'],
          salt: encrypted_events_json['salt'],
        )
        new_user_proofing_event.save
      else
        existing_user_proofing_event.encrypted_events = encrypted_events
        existing_user_proofing_event.cost = encrypted_events_json.cost
        existing_user_proofing_event.salt = encrypted_events_json.salt
        existing_user_proofing_event.save
      end
    end

    private

    def historical_events_enabled?
      return false unless IdentityConfig.store.historical_attempts_api_enabled

      @profile ||= @idv_session.profile
      service_provider ||= @idv_session.service_provider
      service_provider&.attempts_api_enabled?
    end

    def existing_user_proofing_event
      UserProofingEvent.find_by(profile_id: @idv_session.profile.id)
    end

    def encrypt_attempt_events_bundle
      user_uuid = @user_session['idv']['applicant']['uuid']
      encryptor = Encryption::Encryptors::PiiEncryptor.new(@password)
      encryptor.encrypt(@user_session['idv/attempts'].to_json, user_uuid:)
    end
  end
end
