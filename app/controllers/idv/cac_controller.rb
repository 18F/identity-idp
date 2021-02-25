module Idv
  class CacController < ApplicationController
    include PivCacConcern

    before_action :render_404_if_disabled
    before_action :confirm_two_factor_authenticated
    before_action :cac_callback

    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :idv_cac_step_url,
      final_url: :idv_review_url,
      flow: Idv::Flows::CacFlow,
      analytics_id: Analytics::CAC_PROOFING,
    }.freeze

    def redirect_to_piv_cac_service
      Funnel::DocAuth::RegisterStep.new(current_user.id, issuer).call('present_cac', :update, true)
      create_piv_cac_nonce
      redirect_to PivCacService.piv_cac_service_link(
        nonce: piv_cac_nonce,
        redirect_uri: idv_cac_step_url(:present_cac),
      )
    end

    private

    def render_404_if_disabled
      render_not_found unless AppConfig.env.cac_proofing_enabled == 'true'
    end

    def cac_callback
      return unless request.path == idv_cac_step_path(:present_cac) && params[:token]

      result = piv_cac_proofing_form.submit
      analytics.track_event(Analytics::CAC_PROOFING + ' submitted', result.to_h)
      if result.success?
        process_cac_success
      else
        process_cac_fail
      end
    end

    def piv_cac_proofing_form
      @piv_cac_proofing_form ||= PivCacProofingForm.new(
        token: params[:token],
        nonce: piv_cac_nonce,
      )
    end

    def process_cac_success
      store_full_name_or_cn_in_session
      store_proofing_components
      flow_session['Idv::Steps::Cac::PresentCacStep'] = true
      redirect_to idv_cac_step_path(:enter_info)
    end

    def store_proofing_components
      user_id = current_user.id
      Db::ProofingComponent::Add.call(user_id, :document_check, 'pki') # eventually DEERS
      Db::ProofingComponent::Add.call(user_id, :document_type, piv_cac_proofing_form.card_type)
    end

    def store_full_name_or_cn_in_session
      if piv_cac_proofing_form.first_name && piv_cac_proofing_form.last_name
        flow_session['first_name'] = piv_cac_proofing_form.first_name
        flow_session['last_name'] = piv_cac_proofing_form.last_name
      else
        flow_session['piv_cac_cn'] = piv_cac_proofing_form.cn
      end
    end

    def process_cac_fail
      link = view_context.link_to(t('cac_proofing.errors.state_id'), idv_doc_auth_path)
      flash.now[:error] = I18n.t('cac_proofing.errors.does_not_work', link: link)
      Funnel::DocAuth::RegisterStep.new(current_user.id, issuer).
        call('present_cac', :update, false)
    end

    def flow_session
      user_session['idv/cac']
    end
  end
end
