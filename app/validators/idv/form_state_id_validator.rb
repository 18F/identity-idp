module Idv
  module FormStateIdValidator
    extend ActiveSupport::Concern

    STATE_ID_TYPES = %w[drivers_license drivers_permit state_id_card].freeze
    SUPPORTED_JURISDICTIONS = %w[
      AR AZ CA DC DE FL IA ID IL IN KY MD ME MI MS NA ND NE NM PA SD TX VA WA WI
    ].freeze

    included do
      validates :state_id_number, presence: true
      validates :state,
                inclusion: {
                  in: SUPPORTED_JURISDICTIONS,
                  message: I18n.t('idv.errors.unsupported_jurisdiction'),
                }
      validates :state_id_type, inclusion: { in: STATE_ID_TYPES }
    end
  end
end
