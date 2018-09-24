module Flow
  class BaseStep
    def initialize(context, name)
      @context = context
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

    private

    def form_submit
      FormResponse.new(success: true, errors: {})
    end

    def failure(message)
      flow_session[:error_message] = message
      FormResponse.new(success: false, errors: { message: message })
    end

    def flow_params
      params[@name]
    end

    def permit(*args)
      params.require(@name).permit(*args)
    end

    def reset
      @context.flow_session = {}
    end

    delegate :flow_session, :current_user, :params, :steps, to: :@context
  end
end
