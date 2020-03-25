module Px
  class DocAuthController < ApplicationController
    before_action :confirm_two_factor_authenticated

    include IdvSession # remove if we retire the non docauth LOA3 flow
    include Flow::FlowStateMachine

    # TODO update stettings
    FSM_SETTINGS = {
      step_url: :px_doc_auth_step_url,
      final_url: :account_url,
      flow: Px::Flows::DocAuthFlow,
      analytics_id: Analytics::PX_DOC_AUTH,
    }.freeze
  end
end
