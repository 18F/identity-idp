# frozen_string_literal: true

module Test
  class FakeSocureUiController < ApplicationController
    layout 'no_card'

    # TODO: can we not skip this?
    skip_before_action :verify_authenticity_token

    def index
      # TODO: pass these in a more civilized fashion.
      @socure_configurations = FakeSocureController.configurations
      @selected_configuration = FakeSocureController.selected_configuration
      @selected_configuration_body = FakeSocureController.selected_configuration_body
    end

    def update
      puts "params: #{params.permit!.to_h.inspect}"
      puts "params[:selected_configuration]: #{params[:selected_configuration].inspect}"

      FakeSocureController.selected_configuration = params[:selected_configuration]

      # TODO: pass these in a more civilized fashion.
      @socure_configurations = FakeSocureController.configurations
      @selected_configuration = FakeSocureController.selected_configuration
      @selected_configuration_body = FakeSocureController.selected_configuration_body
      render :index
    end

    def document_capture; end
  end
end
