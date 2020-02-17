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
      create_piv_cac_nonce
      redirect_to PivCacService.piv_cac_service_link(
        nonce: piv_cac_nonce,
        redirect_uri: idv_cac_step_url(:present_cac),
      )
    end

    private

    def render_404_if_disabled
      render_not_found unless Figaro.env.cac_proofing_enabled == 'true'
    end

    def cac_callback
      token = params[:token]
      return unless request.path == idv_cac_step_path(:present_cac) && token
      data = PivCacService.decode_token(token)
      cn_array = PivCac::CnFieldsFromSubject.call(data['subject'])
      if cn_array.size > 2 && data['card_type'] == 'cac'
        process_cac_success(cn_array)
      else
        process_cac_fail
      end
    end

    def process_cac_success(cn_array)
      flow_session['Idv::Steps::Cac::PresentCacStep'] = true
      flow_session['first_name'] = cn_array[1]
      flow_session['last_name'] = cn_array[0]
      redirect_to idv_cac_step_path(:enter_info)
    end

    def process_cac_fail
      link = view_context.link_to(t('cac_proofing.errors.state_id'), idv_doc_auth_path)
      flash.now[:error] = I18n.t('cac_proofing.errors.does_not_work', link: link)
    end

    def flow_session
      user_session['idv/cac']
    end
  end
end
