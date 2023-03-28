module Idv
  class NotVerifiedController < ApplicationController
    include FraudReviewConcern

    before_action :confirm_two_factor_authenticated
    before_action :handle_fraud

    def show
      analytics.idv_not_verified_visited
    end
  end
end
