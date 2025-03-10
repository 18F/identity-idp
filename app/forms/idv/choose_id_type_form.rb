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
      return true if DocAuth::Response::ID_TYPE_SLUGS.value? @chosen_id_type
      errors.add(
        :chosen_id_type,
        :invalid,
        message: "
          `choose_id_type` #{@chosen_id_type} is invalid,
          expected one of #{DocAuth::Response::ID_TYPE_SLUGS.values}
        ",
      )
      false
    end
  end
end
