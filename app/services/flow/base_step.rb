module Flow
  class BaseStep
    include Rails.application.routes.url_helpers
    include Failure

    def initialize(flow, name)
      @flow = flow
      @name = name
    end

    def base_call
      form_response = form_submit
      unless form_response.success?
        flow_session[:error_message] = form_response.first_error_message
        return form_response
      end
      create_response(form_response, call)
    end

    def mark_step_complete(step = nil)
      klass = step.nil? ? self.class : steps[step]
      flow_session[klass.to_s] = true
    end

    def mark_step_incomplete(step = nil)
      klass = step.nil? ? self.class : steps[step]
      flow_session.delete(klass.to_s)
      nil
    end

    def self.acceptable_response_object?(obj)
      obj.is_a?(FormResponse) || obj.is_a?(DocAuth::Response)
    end

    # Return a hash of local variables required for step view template
    def extra_view_variables
      {}
    end

    def url_options
      @flow.controller.url_options
    end

    delegate :analytics_visited_event, :analytics_submitted_event, to: :class

    private

    def create_response(form_submit_response, call_response)
      return form_submit_response unless BaseStep.acceptable_response_object?(call_response)
      form_submit_response.merge(call_response)
    end

    def form_submit
      FormResponse.new(success: true)
    end

    def flow_params
      params[@name]
    end

    def permit(*args)
      params.require(:doc_auth).permit(*args)
    end

    def redirect_to(url)
      @flow.redirect_to(url)
    end

    def render_json(json, status: nil)
      @flow.render_json(json, status: status)
    end

    def reset
      @flow.flow_session = {}
    end

    def amzn_trace_id
      request.headers['X-Amzn-Trace-Id']
    end

    delegate :flash, :session, :flow_session, :current_user, :current_sp, :params, :steps, :request,
             :poll_with_meta_refresh, to: :@flow
  end
end
