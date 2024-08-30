# frozen_string_literal: true

class CompletionsCancellationController < ApplicationController
  before_action :confirm_two_factor_authenticated

  def show
    analytics.completions_cancellation_visited
  end
end
