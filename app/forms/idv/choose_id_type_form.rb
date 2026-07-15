# frozen_string_literal: true

module Idv
  class ChooseIdTypeForm
    include ActiveModel::Model

    validate :chosen_id_type_valid?
    attr_reader :chosen_id_type

    def initialize(mdl_enabled: false)
      @mdl_enabled = mdl_enabled
    end

    def submit(params)
      @chosen_id_type = params[:choose_id_type_preference]

      FormResponse.new(success: valid?, errors:)
    end

    def chosen_id_type_valid?
      allowed_types = Idp::Constants::DocumentTypes::PASSPORT_TYPES +
                      Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
      return true if allowed_types.include?(@chosen_id_type)
      return true if @mdl_enabled && chosen_id_type == Idp::Constants::DocumentTypes::MDL

      errors.add(
        :chosen_id_type,
        :invalid,
        message: "
          `chosen_id_type` #{@chosen_id_type} is invalid,
          expected one of #{allowed_types}
        ",
      )
      false
    end
  end
end
