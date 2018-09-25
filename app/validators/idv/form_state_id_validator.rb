module Idv
  module FormStateIdValidator
    extend ActiveSupport::Concern
    include Idv::FormJurisdictionValidator

    STATE_ID_TYPES = %w[drivers_license drivers_permit state_id_card].freeze

    included do
      validates :state_id_number, presence: true,
                                  length: {
                                    maximum: 25,
                                    message: I18n.t('idv.errors.pattern_mismatch.state_id_number'),
                                  }
      validates :state_id_type, inclusion: { in: STATE_ID_TYPES }
    end
  end
end
