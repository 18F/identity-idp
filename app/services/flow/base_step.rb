module Flow
  class BaseStep
    include Rails.application.routes.url_helpers

    def initialize(flow, name)
      @flow = flow
      @form_response = nil
      @name = name
    end

    def base_call
      form_response = form_submit
      return form_response unless form_response.success?
      call
    end

    def mark_step_complete(step = nil)
      klass = step.nil? ? self.class : steps[step]
      flow_session[klass.to_s] = true
    end

    def mark_step_incomplete(step = nil)
      klass = step.nil? ? self.class : steps[step]
      flow_session.delete(klass.to_s)
    end

    private

    def form_submit
      FormResponse.new(success: true, errors: {})
    end

    def failure(message, extra_errors = {})
      flow_session[:error_message] = message
      FormResponse.new(success: false, errors: { message: message }, extra: extra_errors)
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

    def reset
      @flow.flow_session = {}
    end

    delegate :flash, :session, :flow_session, :current_user, :params, :steps, :request, to: :@flow
  end
end
