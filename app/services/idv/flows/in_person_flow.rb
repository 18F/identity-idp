# frozen_string_literal: true

module Idv
  module Flows
    class InPersonFlow < Flow::BaseFlow
      attr_reader :idv_session # this is used by DocAuthBaseStep

      STEP_INDICATOR_STEPS = [
        { name: :find_a_post_office },
        { name: :verify_info },
        { name: :verify_phone },
        { name: :re_enter_password },
        { name: :go_to_the_post_office },
      ].freeze

      STEP_INDICATOR_STEPS_GPO = [
        { name: :find_a_post_office },
        { name: :verify_info },
        { name: :verify_address },
        { name: :secure_account },
        { name: :go_to_the_post_office },
      ].freeze

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, session[name])
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
        {
          pii_like_keypaths: [
            [:proofing_results, :context, :stages, :state_id, :state_id_jurisdiction],
          ],
        }
      end
    end
  end
end
