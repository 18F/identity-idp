# frozen_string_literal: true

module Encryption
  module Encryptors
    # Wraps the small secrets kept beside a retained document image, the per-image AES key of a
    # DocumentArtifact row and the document identifiers of a DocumentMetadata row, with KMS under an
    # encryption context that names the person the document belongs to. KMS is the only party that
    # can unwrap them: a copy of the database and the application secrets does not decrypt a
    # retained image, every unwrap is a KMS call under the person's context so it is audited and
    # cannot be redirected to another person's row, and the multi-region key keeps the rows
    # readable in a region failover, as the profile encryption does.
    class DocumentArtifactEncryptor
      ENCRYPTION_CONTEXT_NAME = 'document-artifact-encryption'

      # @param user_uuid [String] the uuid of the person whose document capture session the row
      #   belongs to; part of the KMS encryption context, so a ciphertext decrypts only for them
      def initialize(user_uuid:)
        raise ArgumentError, 'user_uuid is required to wrap a document artifact' if user_uuid.blank?

        @user_uuid = user_uuid
      end

      # @param plaintext [String]
      # @return [String] the KMS ciphertext, which `KmsClient` prefixes with its key type
      def encrypt(plaintext)
        kms_client.encrypt(plaintext, encryption_context)
      end

      # Only ciphertext this encryptor produced is unwrapped. Anything else, including a value
      # wrapped by the application's static attribute key, is refused rather than handed to KMS as
      # a contextless ciphertext.
      # @param ciphertext [String]
      # @return [String]
      def decrypt(ciphertext)
        unless KmsClient.looks_like_kms?(ciphertext) || KmsClient.looks_like_local_key?(ciphertext)
          raise EncryptionError, 'document artifact ciphertext is not wrapped by KMS'
        end

        kms_client.decrypt(ciphertext, encryption_context)
      end

      private

      attr_reader :user_uuid

      def encryption_context
        {
          'context' => ENCRYPTION_CONTEXT_NAME,
          'user_uuid' => user_uuid,
        }
      end

      def kms_client
        @kms_client ||= KmsClient.new(
          kms_key_id: IdentityConfig.store.aws_kms_multi_region_key_id,
        )
      end
    end
  end
end
