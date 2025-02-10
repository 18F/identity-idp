# frozen_string_literal: true

module AccountReset
  module GrantedTokenValidator
    extend ActiveSupport::Concern

    included do
      validates :token,
                presence: {
                  message: proc do
                    I18n.t('errors.account_reset.granted_token_missing', app_name: APP_NAME)
                  end,
                }
      validate :token_exists, if: :token_present?
      validate :token_not_expired, if: :token_present?
    end

    private

    attr_reader :token

    def token_exists
      return if account_reset_request

      errors.add(
        :token, I18n.t('errors.account_reset.granted_token_invalid', app_name: APP_NAME),
        type: :granted_token_invalid
      )
    end

    def token_not_expired
      return unless account_reset_request&.granted_token_expired?
      errors.add(
        :token, I18n.t('errors.account_reset.granted_token_expired', app_name: APP_NAME),
        type: :granted_token_expired
      )
    end

    def token_present?
      token.present?
    end

    def account_reset_request
      @account_reset_request ||= AccountResetRequest.find_by(granted_token: token)
    end

    def user
      account_reset_request&.user || AnonymousUser.new
    end

    def sp
      return @sp if defined?(@sp)
      @sp = account_reset_request&.requesting_service_provider
    end
  end
end
