# frozen_string_literal: true

# relies on `%w[user_session current_sp current_user]` being available to the controller.
module Idv
  module HistoricalAttemptsConcern
    extend ActiveSupport::Concern

    def record_user_proofing_events(password)
      return unless historical_events_enabled?
      @password = password

      new_events = user_session['idv/attempts'] || []

      if existing_user_proofing_event
        existing_events = JSON.parse(decrypt_user_proofing_events)
        combined_events = existing_events.union(new_events)
        encrypted_events = encrypt_attempt_events_bundle(combined_events)

        existing_user_proofing_event.update_encrypted_events(encrypted_events)
      else
        encrypted_events = encrypt_attempt_events_bundle(new_events)
        encrypted_events_json = JSON.parse(encrypted_events)
        new_user_proofing_event = UserProofingEvent.new(
          encrypted_events:,
          profile_id: current_user.active_profile.id,
          service_providers_sent: [],
          cost: encrypted_events_json['cost'],
          salt: encrypted_events_json['salt'],
        )
        new_user_proofing_event.save
      end

      # Now that proofing events are saved, remove the plaintext events from user_session
      user_session.delete('idv/attempts')
    end

    def cache_user_proofing_events(password)
      return unless historical_events_need_be_sent? && existing_user_proofing_event
      @password = password

      existing_events = decrypt_user_proofing_events
      kms_encrypted_events = SessionEncryptor.new.kms_encrypt(existing_events)
      user_session[:encrypted_proofing_events] = kms_encrypted_events
    end

    private

    def ial2_requested?
      resolved_authn_context_result.identity_proofing_or_ialmax? && current_user.identity_verified?
    end

    def historical_events_need_be_sent?
      return false unless historical_events_enabled?

      sent_to_aaca = existing_user_proofing_event&.service_providers_sent&.include?(
        current_sp.issuer,
      )

      return !sent_to_aaca
    end

    def historical_events_enabled?
      return false unless IdentityConfig.store.historical_attempts_api_enabled

      current_sp&.attempts_api_enabled? && ial2_requested?
    end

    def existing_user_proofing_event
      @existing_user_proofing_event ||= UserProofingEvent.find_by(
        profile_id: current_user.active_profile.id,
      )
    end

    def encrypt_attempt_events_bundle(bundle)
      pii_encryptor.encrypt(bundle.to_json, user_uuid:)
    end

    def decrypt_user_proofing_events
      pii_encryptor.decrypt(existing_user_proofing_event['encrypted_events'], user_uuid:)
    end

    def pii_encryptor
      @pii_encryptor ||= Encryption::Encryptors::PiiEncryptor.new(@password)
    end

    def user_uuid
      @user_uuid ||= current_user['uuid']
    end
  end
end
