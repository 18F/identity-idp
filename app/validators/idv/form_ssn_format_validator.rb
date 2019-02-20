module Idv
  module FormSsnFormatValidator
    extend ActiveSupport::Concern

    included do
      validates :ssn, presence: true
      validates_format_of :ssn,
                          with: /\A\d{3}-?\d{2}-?\d{4}\z/,
                          message: I18n.t('idv.errors.pattern_mismatch.ssn'),
                          allow_blank: false
    end
  end
end
