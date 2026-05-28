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

  def write_events(password:, attempt_events:)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)
    encrypted_events_json = encryptor.encrypt(attempt_events.to_json, user_uuid: user.uuid)

    encrypted_doc_writer.write_encrypted_attempt_events(
      file_path: attempt_events_file_path,
      encrypted_attempt_events: formatted_events(password_encrypted_events: encrypted_events_json),
      name: profile.encrypted_attempts_file_reference,
    )
  end

  def decrypt_events(password:)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)

    data = JSON.parse(
      attempt_data_retriever.retrieve_user_proofing_events(
        file_path: attempt_events_file_path,
        file_name: profile.encrypted_attempts_file_reference,
      ),
    )
    encryptor.decrypt(data['password_encrypted_events'], user_uuid: user.uuid)
  end

  private

  def formatted_events(password_encrypted_events:)
    { password_encrypted_events: }.to_json
  end

  # We will need the data in storage to look like this:
  # {
  #   password_encrypted_events: {
  #     encrypted_data: "encrypted_string",
  #     cost: 'cost',
  #     salt: 'salt'
  #     },
  #   personal_key_encrypted_events: {
  #     encrypted_data: "encrypted_string",
  #     cost: 'cost',
  #     salt: 'salt'
  #     }
  # }

  def user
    @user ||= profile.user
  end

  def encrypted_doc_writer
    @encrypted_doc_writer ||= EncryptedDocStorage::DocWriter.new(
      s3_enabled: historical_attempts_s3_storage_enabled?,
    )
  end

  def attempt_data_retriever
    @attempt_data_retriever ||= EncryptedDocStorage::AttemptDataRetriever.new(
      s3_enabled: historical_attempts_s3_storage_enabled?,
    )
  end

  def attempt_events_file_path
    "attempt_events/#{profile.user.uuid}/#{profile.id}"
  end

  def historical_attempts_s3_storage_enabled?
    IdentityConfig.store.historical_attempts_s3_storage_enabled
  end
end
