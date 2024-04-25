# frozen_string_literal: true

class CompletionsCancellationController < ApplicationController
  before_action :confirm_two_factor_authenticated

  def show
    analytics.exit_to_sp_confirmation_page_visited
  end
end
