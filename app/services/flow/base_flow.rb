module Flow
  class BaseFlow
    attr_accessor :flow_session
    attr_reader :steps, :actions, :current_user, :params, :request

    def initialize(controller, steps, actions, session)
      @controller = controller
      @steps = steps.with_indifferent_access
      @actions = actions.with_indifferent_access
      @redirect = nil
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

    def handle(step)
      @flow_session[:error_message] = nil
      @flow_session[:notice] = nil
      handler = steps[step] || actions[step]
      return failure("Unhandled step #{step}") unless handler
      wrap_send(handler)
    end

    private

    def wrap_send(handler)
      obj = handler.new(self)
      value = obj.base_call
      form_response(obj, value)
    end

    def form_response(obj, value)
      response = acceptable_response_object?(value) ? value : create_form_response(value)
      obj.mark_step_complete if response.success?
      response
    end

    def create_form_response(obj)
      success = obj.respond_to?(:success?) ? obj.success? : true
      errors = obj.respond_to?(:errors?) ? obj.errors? : {}
      extra = obj.respond_to?(:extra?) ? obj.extra? : {}
      errors = {} if errors.blank?
      FormResponse.new(success: success, errors: errors, extra: extra)
    end

    def acceptable_response_object?(obj)
      obj.is_a?(FormResponse) || obj.is_a?(DocAuth::Response)
    end

    delegate :flash, :session, :current_user, :params, :request, to: :@controller
  end
end
