module Idv
  module FormConsentValidator
    extend ActiveSupport::Concern

    included do
      attr_accessor :ial2_consent_given
      validate :consent_given
    end

    def consent_given
      return unless !ial2_consent_given

      errors.add :consent_must_be_given, message: "MUST GIVE CONSENT OIEJFOWJID"
    end
  end
end
