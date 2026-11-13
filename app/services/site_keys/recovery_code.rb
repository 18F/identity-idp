# frozen_string_literal: true

module SiteKeys
  # Site key recovery codes share the personal key format, so the same input and display
  # partials apply.
  module RecoveryCode
    def self.generate
      RandomPhrase.new(num_words: IdentityConfig.store.recovery_code_length || 4).to_s.tr(' ', '-')
    end

    def self.normalize(code)
      normalized = PersonalKeyGenerator.new(nil).normalize(code.to_s)
      normalized unless normalized == PersonalKeyGenerator::INVALID_CODE
    end
  end
end
