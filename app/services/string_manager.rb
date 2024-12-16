# frozen_string_literal: true

class StringManager
  @@instance = nil

  def self.instance
    @@instance ||= self.new
  end

  LOCALES = %w[en es fr zh].freeze

  TranslationRequest = Struct.new(:locale, :key, :options, :result, :translations)

  attr_reader :translation_requests

  def initialize
    reset_tracking
  end

  def reset_tracking
    Rails.logger.info 'StringManager#reset_tracking'
    @translation_requests = []
  end

  def record_translation_request(locale:, key:, options:, result:, translations:)
    Rails.logger.info "StringManager#record_translation_request(locale: #{locale}, key: #{key}, options: #{options}, result: #{result}, translations: #{translations})"
    @translation_requests << TranslationRequest.new(
      locale:,
      key:,
      options:,
      result:,
      translations:,
    )
  end
end
