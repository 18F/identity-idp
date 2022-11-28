module Flow
  class BaseFlow
    include Failure

    attr_accessor :flow_session
    attr_reader :steps, :actions, :current_user, :current_sp, :params, :request, :json,
                :http_status, :controller

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

    def step_handler(step)
      steps[step] || actions[step]
    end

    def handle(step)
      @flow_session[:error_message] = nil
      handler = step_handler(step)
      return failure("Unhandled step #{step}") unless handler
      wrap_send(handler)
    end

    def extra_view_variables(step)
      handler = step_handler(step)
      return failure("Unhandled step #{step}") unless handler
      obj = handler.new(self)
      obj.extra_view_variables
    end

    def extra_analytics_properties
      {}
    end

    def flow_path
      'standard'
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
      FormResponse.new(success: true)
    end

    delegate :flash, :session, :current_user, :current_sp, :params, :request,
             :poll_with_meta_refresh, :analytics, :irs_attempts_api_tracker, to: :@controller
  end
end
