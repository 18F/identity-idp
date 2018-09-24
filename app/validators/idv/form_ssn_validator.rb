module Idv
  module FormSsnValidator
    extend ActiveSupport::Concern

    included do
      validates :ssn, presence: true
      validate :ssn_is_unique
      validates_format_of :ssn,
                          with: /\A\d{3}-?\d{2}-?\d{4}\z/,
                          message: I18n.t('idv.errors.pattern_mismatch.ssn'),
                          allow_blank: false
    end

    def duplicate_ssn?
      return true if any_matching_ssn_signatures?(ssn_signature) ||
                     ssn_is_duplicate_with_old_key?
      false
    end

    private

    def ssn_signature(key = Pii::Fingerprinter.current_key)
      Pii::Fingerprinter.fingerprint(ssn, key) if ssn
    end

    def ssn_is_unique
      errors.add :ssn, I18n.t('idv.errors.duplicate_ssn') if duplicate_ssn?
    end

    def ssn_is_duplicate_with_old_key?
      signatures = KeyRotator::Utils.old_keys(:hmac_fingerprinter_key_queue).map do |key|
        ssn_signature(key)
      end
      any_matching_ssn_signatures?(signatures)
    end

    def any_matching_ssn_signatures?(signatures)
      Profile.where.not(user_id: @user.id).where(ssn_signature: signatures).any?
    end
  end
end
