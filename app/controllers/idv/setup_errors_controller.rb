module Idv
  class SetupErrorsController < ApplicationController
    include FraudReviewConcern

    before_action :confirm_two_factor_authenticated
    before_action :handle_fraud

    def show
      analytics.idv_setup_errors_visited
    end
  end
end
