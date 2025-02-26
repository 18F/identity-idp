# frozen_string_literal: true

module Idv
  class ChooseIdTypeForm
    include ActiveModel::Model

    attr_reader :chosen_id_type

    def initialize(chosen_id_type = nil)
      @chosen_id_type = chosen_id_type
    end

    def submit(params)
      @chosen_id_type = params[:choose_id_type_preference]

      FormResponse.new(success: valid?, errors: errors)
    end
  end
end
