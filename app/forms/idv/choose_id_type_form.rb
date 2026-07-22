# frozen_string_literal: true

module Idv
  class ChooseIdTypeForm
    include ActiveModel::Model

    validate :chosen_id_type_valid?
    attr_reader :chosen_id_type

    def initialize(mdl_enabled: false, passport_cards_enabled: false)
      @mdl_enabled = mdl_enabled
      @passport_cards_enabled = passport_cards_enabled
    end

    def submit(params)
      @chosen_id_type = params[:choose_id_type_preference]

      FormResponse.new(success: valid?, errors:)
    end

    def chosen_id_type_valid?
      return true if allowed_types.include?(chosen_id_type)

      errors.add(
        :chosen_id_type,
        :invalid,
        message: "
          `chosen_id_type` #{chosen_id_type} is invalid,
          expected one of #{allowed_types}
        ",
      )
      false
    end

    private

    def allowed_types
      types = Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES +
              Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
      types += [Idp::Constants::DocumentTypes::PASSPORT_CARD] if @passport_cards_enabled
      types += [Idp::Constants::DocumentTypes::MDL] if @mdl_enabled
      types
    end
  end
end
