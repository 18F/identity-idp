# frozen_string_literal: true

module Redirect
  class PartnerExitController < ApplicationController
    before_action :validate_sp_exists

    def show
      analytics.exit_to_sp_confirmation_page_visited
    end
  end
end
