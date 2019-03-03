module Idv
  module RequestTokenValidator
    extend ActiveSupport::Concern

    included do
      validates :token, presence: { message: I18n.t('errors.capture_doc.token_missing') }
      validate :token_exists, if: :token_present?
      validate :token_not_expired, if: :token_present?
    end

    private

    attr_reader :token

    def token_exists
      return if capture_doc_request

      errors.add(:token, I18n.t('errors.capture_doc.token_invalid'))
    end

    def token_not_expired
      return unless capture_doc_request&.expired?
      errors.add(:token, I18n.t('errors.capture_doc.token_expired'))
    end

    def token_present?
      token.present?
    end

    def capture_doc_request
      @capture_doc_request ||= DocCapture.find_by(request_token: token)
    end
  end
end
