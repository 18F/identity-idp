module Idv
  module FormJurisdictionValidator
    extend ActiveSupport::Concern

    SUPPORTED_JURISDICTIONS = %w[
      AR AZ CO DC DE FL IA ID IL IN KY MA MD ME MI MS MT ND NE NJ NM PA SD TX VA WA WI WY
    ].freeze

    included do
      validates :state,
                inclusion: {
                  in: SUPPORTED_JURISDICTIONS,
                  message: I18n.t('idv.errors.unsupported_jurisdiction'),
                }
    end

    def unsupported_jurisdiction?
      !SUPPORTED_JURISDICTIONS.include?(state)
    end
  end
end
