# frozen_string_literal: true

# relies on `%w[user_session current_sp current_user]` being available to the controller.
module Idv
  module HistoricalAttemptsConcern
    extend ActiveSupport::Concern

    def record_user_proofing_events(password)
      return unless historical_events_enabled?
      # TODO: move UserProofingEvent creation to the Profile object
      @password = password

      new_events = user_session['idv/attempts'] || []

      encrypted_events_json = encrypt_attempt_events_bundle(new_events)
      encrypted_events = JSON.parse(encrypted_events_json)

      # TODO: Write encrypted_events['encrypted_data'] to S3
      # TODO: Save reference to S3 object in current_user.active_profile

      new_user_proofing_event = current_user
        .active_profile
        .build_user_proofing_event(
          cost: encrypted_events['cost'],
          salt: encrypted_events['salt'],
        )

      new_user_proofing_event.save

      # Now that proofing events are saved, remove the plaintext events from user_session
      user_session.delete('idv/attempts')
    end

    def cache_user_proofing_events(password)
      return unless historical_events_need_be_sent?
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
      return false if existing_user_proofing_event.blank?

      return !existing_user_proofing_event.already_sent_to_sp?(current_sp.id)
    end

    def historical_events_enabled?
      return false unless IdentityConfig.store.historical_attempts_api_enabled

      current_sp&.attempts_api_enabled? && ial2_requested?
    end

    def existing_user_proofing_event
      @existing_user_proofing_event ||= current_user.active_profile.user_proofing_event
    end

    def encrypt_attempt_events_bundle(bundle)
      pii_encryptor.encrypt(bundle.to_json, user_uuid:)
    end

    def decrypt_user_proofing_events
      # TODO: Retrieve encrypted_events from S3 or locally
      # Currently this is not in use, so passing in dummy data
      data = pii_encryptor.encrypt(
        [
          { 'idv-ssn-submitted' => { 'user_uuid' => user_uuid } },
        ].to_json,
        user_uuid:,
      )
      pii_encryptor.decrypt(data, user_uuid:)
    end

    def pii_encryptor
      @pii_encryptor ||= Encryption::Encryptors::PiiEncryptor.new(@password)
    end

    def user_uuid
      @user_uuid ||= current_user['uuid']
    end
  end
end
