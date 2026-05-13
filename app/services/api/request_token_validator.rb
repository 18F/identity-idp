# frozen_string_literal: true

module Api
  class RequestTokenValidator
    include ActiveModel::Model

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

    def sp_issuer
      service_provider&.issuer
    end

    private

    attr_reader :bearer, :issuer, :token

    def config_data_exists
      raise NotImplementedError
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
        scrypt_salt = valid_token['cost'] + OpenSSL::Digest::SHA256.hexdigest(valid_token['salt'])
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
      @config_data ||= config.find do |issuer_config|
        issuer_config['issuer'] == issuer
      end
    end

    def config_data_exists?
      config_data.present?
    end

    def service_provider
      @service_provider ||= ServiceProvider.find_by(issuer:)
    end

    def config
      NotImplementedError
    end
  end
end
