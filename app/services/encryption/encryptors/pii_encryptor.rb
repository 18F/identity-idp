module Encryption
  module Encryptors
    class PiiEncryptor
      extend Forwardable

      def initialize(password:, salt:, cost: nil)
        user_access_key = UserAccessKey.new(
          password: password,
          cost: cost,
          salt: salt
        )
        @encryptor = UserAccessKeyEncryptor.new(user_access_key)
      end

      def_delegators :encryptor, :encrypt, :decrypt

      private

      attr_reader :encryptor
    end
  end
end
