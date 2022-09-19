module Idv
  module Steps
    module InheritedProofing
      class GetStartedStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :getting_started

        def initialize(flow)
          super

          # Rails.logger.debug "xyzzy: @idv_session: #{@idv_session}"
          # Rails.logger.debug "xyzzy: flow: #{flow}"
          # # # TODO: Verify. Compare app/services/idv/flows/in_person_flow.rb
          # # @flow_session ||= {}
          # # # TODO: current_user is nil when this is hit!
          # # @flow_session[:pii_from_user] ||= { uuid: current_user.uuid }
          # # applicant = @idv_session['applicant'] || {}
          # # @flow_session[:pii_from_user] = @flow_session[:pii_from_user].to_h.merge(applicant)
        end

        def call
          Rails.logger.debug('xyzzy: in GetStartedStep')
        end
      end
    end
  end
end
