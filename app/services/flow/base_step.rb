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

    # :reek:FeatureEnvy
    def failure(message, extra = nil)
      flow_session[:error_message] = message
      form_response_params = { success: false, errors: { message: message } }
      if extra.present?
        flow_session[:notice] = extra[:notice]
        form_response_params[:extra] = extra unless extra.nil?
      end
      FormResponse.new(form_response_params)
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
