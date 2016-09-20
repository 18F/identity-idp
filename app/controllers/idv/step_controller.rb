module Idv
  class StepController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_session_started
    before_action :confirm_idv_attempts_allowed
  end
end
