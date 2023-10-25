# frozen_string_literal: true

module Idv
  class NotVerifiedController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      analytics.idv_not_verified_visited
    end
  end
end
