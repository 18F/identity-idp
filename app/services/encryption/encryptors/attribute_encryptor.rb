module Encryption
  module Encryptors
    class AttributeEncryptor
      def encrypt(plaintext)
        user_access_key = self.class.load_or_init_user_access_key(
          key: current_key, cost: current_cost
        )
        UserAccessKeyEncryptor.new(user_access_key).encrypt(plaintext)
      end

      def decrypt(ciphertext)
        encryption_keys_with_cost.each do |key_with_cost|
          key = key_with_cost.fetch(:key)
          cost = key_with_cost.fetch(:cost)
          result = try_decrypt(ciphertext, key: key, cost: cost)
          return result unless result.nil?
        end
        raise Pii::EncryptionError, 'unable to decrypt attribute with any key'
      end

      def stale?
        stale
      end

      def self.load_or_init_user_access_key(key:, cost:)
        @_scypt_hashes_by_key ||= {}
        scrypt_hash = @_scypt_hashes_by_key["#{key}:#{cost}"]
        return UserAccessKey.new(scrypt_hash: scrypt_hash) if scrypt_hash.present?
        uak = UserAccessKey.new(password: key, salt: key, cost: cost)
        @_scypt_hashes_by_key["#{key}:#{cost}"] = uak.as_scrypt_hash
        uak
      end

      private

      attr_accessor :stale

      def try_decrypt(ciphertext, key:, cost:)
        user_access_key = self.class.load_or_init_user_access_key(key: key, cost: cost)
        begin
          result = UserAccessKeyEncryptor.new(user_access_key).decrypt(ciphertext)
          self.stale = key != current_key
          result
        rescue Pii::EncryptionError
          nil
        end
      end

      def encryption_keys_with_cost
        @encryption_keys_with_cost ||= [{ key: current_key, cost: current_cost }] + old_keys
      end

      def current_key
        Figaro.env.attribute_encryption_key
      end

      def current_cost
        Figaro.env.attribute_cost
      end

      def old_keys
        JSON.parse(Figaro.env.attribute_encryption_key_queue, symbolize_names: true)
      end
    end
  end
end
