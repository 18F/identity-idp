module Idv
  module FormStateIdValidator
    extend ActiveSupport::Concern
    include Idv::FormJurisdictionValidator

    STATE_ID_TYPES = %w[drivers_license drivers_permit state_id_card].freeze

    included do
      validates :state_id_number, presence: true
      validates :state_id_type, inclusion: { in: STATE_ID_TYPES }
    end
  end
end
