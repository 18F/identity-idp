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
      @allowed_types ||= [
        *state_id_types,
        Idp::Constants::DocumentTypes::PASSPORT,
        @passport_cards_enabled ? Idp::Constants::DocumentTypes::PASSPORT_CARD : nil,
      ].compact
    end

    # mDL is a supported state ID type, but is not offered in every flow (e.g.
    # in-person proofing), so exclude it unless this flow enables it.
    def state_id_types
      types = Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
      return types if @mdl_enabled

      types - [Idp::Constants::DocumentTypes::MDL]
    end
  end
end
