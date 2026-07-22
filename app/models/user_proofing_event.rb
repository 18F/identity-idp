# frozen_string_literal: true

class UserProofingEvent < ApplicationRecord
  belongs_to :profile
  self.ignored_columns = %w[encrypted_events service_providers_sent cost salt]

  # @param [Integer] id ID of service provider to add to "sent" list
  def add_sp_sent(id)
    return if self.service_provider_ids_sent.include?(id)

    self.service_provider_ids_sent.push(id)
    self.save!
  end

  def already_sent_to_sp?(id)
    service_provider_ids_sent.include?(id)
  end

  # Stored data looks like this:
  # {
  #   'password_encrypted_events' => {
  #     encrypted_data: "encrypted_string",
  #     cost: 'cost',
  #     salt: 'salt'
  #     }.to_json,
  #   'personal_key_encrypted_events' => {
  #     encrypted_data: "encrypted_string",
  #     cost: 'cost',
  #     salt: 'salt'
  #     }.to_json
  # }

  def write_events(attempt_events:, password:, personal_key:)
    encrypted_attempt_events = {
      password_encrypted_events: encrypted_json(password, attempt_events),
      personal_key_encrypted_events: encrypted_json(personal_key, attempt_events),
    }.to_json

    write_attempts_data(encrypted_attempt_events:)
  end

  def decrypt_events(password:)
    attempts_data = retrieved_attempts_data
    return nil if attempts_data.blank?
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)

    encryptor.decrypt(attempts_data['password_encrypted_events'], user_uuid: user.uuid)
  end

  def reencrypt_recovery_attempts_data(attempt_events:, personal_key:)
    personal_key_encrypted_events = encrypted_json(personal_key, attempt_events)

    # merge the new personal key encrypted data in
    encrypted_attempt_events = retrieved_attempts_data.merge(
      'personal_key_encrypted_events' => personal_key_encrypted_events,
    ).to_json
    # rewrite the data
    write_attempts_data(encrypted_attempt_events:)
  end

  def recover_attempt_events(personal_key:)
    attempt_data = retrieved_attempts_data
    return nil if attempt_data.blank?
    encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)

    encryptor.decrypt(
      attempt_data['personal_key_encrypted_events'],
      user_uuid: user.uuid,
    )
  end

  private

  def encrypted_json(key, data)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(key)
    encryptor.encrypt(data.to_json, user_uuid: user.uuid)
  end

  def retrieved_attempts_data
    data = attempt_data_handler.retrieve_user_proofing_events(
      file_path: attempt_events_file_path,
      file_name: profile.encrypted_attempts_file_reference,
    )

    JSON.parse(data) if data.present?
  end

  def user
    @user ||= profile.user
  end

  def write_attempts_data(encrypted_attempt_events:)
    encrypted_doc_writer.write_encrypted_attempt_events(
      file_path: attempt_events_file_path,
      encrypted_attempt_events:,
      # on first write name will be `nil`. the DocWriter will take care of that
      name: profile.encrypted_attempts_file_reference,
    )
  end

  def encrypted_doc_writer
    @encrypted_doc_writer ||= EncryptedDocStorage::DocWriter.new(
      s3_enabled: historical_attempts_s3_storage_enabled?,
    )
  end

  def attempt_data_handler
    @attempt_data_handler ||= EncryptedDocStorage::AttemptDataHandler.new(
      s3_enabled: historical_attempts_s3_storage_enabled?,
    )
  end

  def attempt_events_file_path
    "attempt_events/#{user.uuid}/#{profile.id}"
  end

  def historical_attempts_s3_storage_enabled?
    IdentityConfig.store.historical_attempts_s3_storage_enabled
  end
end
