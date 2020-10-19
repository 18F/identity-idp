module Flow
  class BaseFlow
    attr_accessor :flow_session
    attr_reader :steps, :actions, :current_user, :params, :request, :json, :http_status

    def initialize(controller, steps, actions, session)
      @controller = controller
      @steps = steps.with_indifferent_access
      @actions = actions.with_indifferent_access
      @redirect = nil
      @json = nil
      @flow_session = session
    end

    def next_step
      return @redirect if @redirect
      step, _klass = steps.detect do |_step, klass|
        !@flow_session[klass.to_s]
      end
      step
    end

    def redirect_to(url)
      @redirect = url
    end

    def render_json(json, status: nil)
      @json = json
      @http_status = status || :ok
    end

    def handle(step)
      @flow_session[:error_message] = nil
      @flow_session[:notice] = nil
      handler = steps[step] || actions[step]
      return failure("Unhandled step #{step}") unless handler
      wrap_send(handler)
    end

    def mark_step_complete(step)
      return if step.nil?

      klass = steps[step]
      return if klass.nil?

      flow_session[klass.to_s] = true
    end

    def extra_view_variables(step)
      handler = steps[step] || actions[step]
      return failure("Unhandled step #{step}") unless handler
      obj = handler.new(self)
      obj.extra_view_variables
    end

    private

    def wrap_send(handler)
      obj = handler.new(self)
      value = obj.base_call
      form_response(obj, value)
    end

    def form_response(obj, value)
      response = BaseStep.acceptable_response_object?(value) ? value : successful_response
      obj.mark_step_complete if response.success?
      response
    end

    def successful_response
      FormResponse.new(success: true, errors: {})
    end

    delegate :flash, :session, :current_user, :params, :request, :poll_with_meta_refresh,
             to: :@controller
  end
end
