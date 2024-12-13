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
    @translation_requests = []
  end

  def reset_tracking
    @translation_requests = []
  end

  def record_translation_request(locale:, key:, options:, result:, translations:)
    @translation_requests << TranslationRequest.new(
      locale:,
      key:,
      options:,
      result:,
      translations:,
    )
  end
end
