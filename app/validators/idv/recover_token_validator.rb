module Idv
  module RecoverTokenValidator
    extend ActiveSupport::Concern

    included do
      validates :token, presence: { message: I18n.t('errors.capture_doc.token_missing') }
      validate :token_exists, if: :token_present?
      validate :token_not_expired, if: :token_present?
    end

    private

    attr_reader :token

    def token_exists
      return if recover_request

      errors.add(:token, I18n.t('errors.capture_doc.token_invalid'))
    end

    def token_not_expired
      return unless recover_request&.expired?
      errors.add(:token, I18n.t('errors.capture_doc.token_expired'))
    end

    def token_present?
      token.present?
    end

    def recover_request
      @recover_request ||= AccountRecoveryRequest.find_by(request_token: token)
    end
  end
end
