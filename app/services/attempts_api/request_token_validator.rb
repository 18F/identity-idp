# frozen_string_literal: true

module AttemptsApi
  class RequestTokenValidator
    include ActiveModel::Model

    attr_reader :bearer, :issuer, :token

    validates :token, :issuer, :bearer, presence: true
    validates :bearer, comparison: { equal_to: 'Bearer' }
    validate :config_data_exists
    validate :service_provider_exists, if: :config_data_exists?
    validate :valid_request_token?, if: :config_data_exists?

    def initialize(auth_request_header)
      case auth_request_header&.split(' ', 3)
      in String => bearer, String => issuer, String => token
        @bearer = bearer
        @issuer = issuer
        @token = token
      else
        @bearer = nil
        @issuer = nil
        @token = nil
      end
    end

    private

    def config_data_exists
      return if config_data_exists?

      errors.add(
        :issuer,
        :not_authorized,
        message: 'Issuer is not authorized to use Attempts API',
      )
    end

    def service_provider_exists
      return if service_provider.present?

      errors.add(
        :service_provider,
        :not_authorized,
        message: 'ServiceProvider does not exist',
      )
    end

    def valid_request_token?
      return if config_data['tokens'].any? do |valid_token|
        scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(valid_token['salt'])
        scrypted = SCrypt::Engine.hash_secret token, scrypt_salt, 32
        hashed_req_token = SCrypt::Password.new(scrypted).digest
        ActiveSupport::SecurityUtils.secure_compare(valid_token['value'], hashed_req_token)
      end

      errors.add(
        :request_token,
        :not_valid,
        message: 'Request token is not valid',
      )
    end

    def config_data
      @config_data ||= IdentityConfig.store.allowed_attempts_providers.find do |config|
        config['issuer'] == issuer
      end
    end

    def config_data_exists?
      config_data.present?
    end

    def cost
      IdentityConfig.store.scrypt_cost
    end

    def service_provider
      @service_provider ||= ServiceProvider.find_by(issuer:)
    end
  end
end
