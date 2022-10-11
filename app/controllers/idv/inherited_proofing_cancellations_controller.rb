module Idv
  class InheritedProofingCancellationsController < ApplicationController
    include IdvSession
    include GoBackHelper
    include InheritedProofing404Concern

    before_action :confirm_idv_needed

    def new
      # NOTE: Uncomment this when analytics are implemented.
      # properties = ParseControllerFromReferer.new(request.referer).call
      # analytics.idv_inherited_proofing_cancellation_visited(step: params[:step], **properties)
      self.session_go_back_path = go_back_path || idv_inherited_proofing_path
      @presenter = CancellationsPresenter.new(
        sp_name: decorated_session.sp_name,
        url_options: url_options,
      )
    end

    def update
      # NOTE: Uncomment this when analytics are implemented.
      # analytics.idv_inherited_proofing_cancellation_go_back(step: params[:step])
      redirect_to session_go_back_path || idv_inherited_proofing_path
    end

    def destroy
      # analytics.idv_inherited_proofing_cancellation_confirmed(step: params[:step])
      cancel_session
      render json: { redirect_url: cancelled_redirect_path }
    end

    private

    def cancel_session
      cancel_idv_session
      cancel_user_session
    end

    def cancel_idv_session
      idv_session = user_session[:idv]
      idv_session&.clear
    end

    def cancel_user_session
      user_session['idv'] = {}
    end

    def cancelled_redirect_path
      return return_to_sp_failure_to_proof_path(location_params) if decorated_session.sp_name

      account_path
    end

    def session_go_back_path=(path)
      idv_session.go_back_path = path
    end

    def session_go_back_path
      idv_session.go_back_path
    end

    # IdvSession Concern overrides

    def confirm_idv_vendor_session_started
      return if flash[:allow_confirmations_continue]

      redirect_to idv_inherited_proofing_url unless idv_session.proofing_started?
    end

    def hybrid_session?
      false
    end

    # NOTE: Override and use Inherited Proofing (IP)-specific :throttle_type
    # if current IDV-specific :idv_resolution type is unacceptable!
    # def idv_attempter_throttled?
    #   ...
    # end

    # IdvSession Concern > EffectiveUser Concern overrides

    def effective_user_id
      current_user&.id
    end
  end
end
