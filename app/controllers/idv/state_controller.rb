module Idv
  class StateController < ApplicationController
    def new
      @state_form = Idv::StateForm.new
      # analytics.track_event(Analytics::IDV_STATE_VISIT)
    end

    def create
      @state_form = Idv::StateForm.new
      result = @state_form.submit(state_params)

      # analytics.track_event(Analytics::IDV_STATE_FORM, result.to_h)

      if result.success?
        # put state in session
        redirect_to idv_session_url
      else
        render :new
      end
    end

    def state_params
      params.require(:state).permit(*Idv::StateForm::ATTRIBUTES)
    end
  end
end
