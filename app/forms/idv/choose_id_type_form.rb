# frozen_string_literal: true

module Idv
  class ChooseIdTypeForm
    include ActiveModel::Model

    validate :chosen_id_type_valid?
    attr_reader :chosen_id_type

    def initialize(chosen_id_type = nil)
      @chosen_id_type = chosen_id_type
    end

    def submit(params)
      @chosen_id_type = params[:choose_id_type_preference]

      FormResponse.new(success: chosen_id_type_valid?, errors: errors)
    end

    def chosen_id_type_valid?
      return true if Idp::Constants::DocumentTypes::SUPPORTED_ID_TYPES.include?(@chosen_id_type)
      return true if mdl_selected_and_enabled?
      errors.add(
        :chosen_id_type,
        :invalid,
        message: "
          `chosen_id_type` #{@chosen_id_type} is invalid,
          expected one of #{Idp::Constants::DocumentTypes::SUPPORTED_ID_TYPES}
        ",
      )
      false
    end

    def mdl_selected_and_enabled?
      @chosen_id_type == Idp::Constants::DocumentTypes::MDL &&
        IdentityConfig.store.mdl_verification_enabled
    end
  end
end
