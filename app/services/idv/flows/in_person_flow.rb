module Idv
  module Flows
    class InPersonFlow < Flow::BaseFlow
      attr_reader :idv_session # this is used by DocAuthBaseStep

      STEPS = {
        state_id: Idv::Steps::InPerson::StateIdStep, # info from state id
      }.freeze

      ACTIONS = {
        cancel_update_state_id: Idv::Actions::InPerson::CancelUpdateStateIdAction,
        redo_state_id: Idv::Actions::InPerson::RedoStateIdAction,
      }.freeze

      STEP_INDICATOR_STEPS = [
        { name: :find_a_post_office },
        { name: :verify_info },
        { name: :verify_phone_or_address },
        { name: :secure_account },
        { name: :go_to_the_post_office },
      ].freeze

      STEP_INDICATOR_STEPS_GPO = [
        { name: :find_a_post_office },
        { name: :verify_info },
        { name: :secure_account },
        { name: :get_a_letter },
        { name: :go_to_the_post_office },
      ].freeze

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
        @flow_session ||= {}
        @flow_session[:pii_from_user] ||= { uuid: current_user.uuid }
        # there may be data in @idv_session to copy to @flow_session
        applicant = @idv_session['applicant'] || {}
        @flow_session[:pii_from_user] = @flow_session[:pii_from_user].to_h.merge(applicant)
      end

      def self.session_idv(session)
        session[:idv] ||= {}
      end

      def extra_analytics_properties
        extra = {
          pii_like_keypaths: [
            [:same_address_as_id],
            [:proofing_results, :context, :stages, :state_id, :state_id_jurisdiction],
          ],
        }
        unless @flow_session[:pii_from_user]&.[](:same_address_as_id).nil?
          extra[:same_address_as_id] =
            @flow_session[:pii_from_user][:same_address_as_id].to_s == 'true'
        end
        extra
      end
    end
  end
end
