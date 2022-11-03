module Flow
  module FlowStateMachine
    extend ActiveSupport::Concern

    included do
      before_action :initialize_flow_state_machine
      before_action :ensure_correct_step, only: :show
    end

    attr_accessor :flow

    def index
      redirect_to_step(next_step)
    end

    def show
      track_step_visited
      render_step(current_step, flow.flow_session)
    end

    def update
      step = current_step
      result = flow.handle(step)

      increment_step_name_counts
      analytics.public_send(
        flow.step_handler(step).analytics_submitted_event,
        **result.to_h.merge(analytics_properties),
      )

      register_update_step(step, result)
      if flow.json
        render json: flow.json, status: flow.http_status
        return
      end
      flow_finish and return unless next_step
      render_update(step, result)
    end

    def poll_with_meta_refresh(seconds)
      @meta_refresh = seconds
    end

    private

    def current_step
      params[:step]&.underscore
    end

    def track_step_visited
      increment_step_name_counts
      analytics.public_send(
        flow.step_handler(current_step).analytics_visited_event,
        **analytics_properties,
      )

      Funnel::DocAuth::RegisterStep.new(user_id, issuer).call(current_step, :view, true)
    end

    def user_id
      current_user ? current_user.id : user_id_from_token
    end

    def user_id_from_token
      current_session[:doc_capture_user_id]
    end

    def register_update_step(step, result)
      Funnel::DocAuth::RegisterStep.new(user_id, issuer).call(step, :update, result.success?)
    end

    def issuer
      sp_session[:issuer]
    end

    def initialize_flow_state_machine
      klass = self.class
      flow = klass::FLOW_STATE_MACHINE_SETTINGS[:flow]
      @name = klass.name.underscore.gsub('_controller', '')
      @namespace = flow.name.split('::').first.underscore
      @step_url = klass::FLOW_STATE_MACHINE_SETTINGS[:step_url]
      @final_url = klass::FLOW_STATE_MACHINE_SETTINGS[:final_url]
      @analytics_id = klass::FLOW_STATE_MACHINE_SETTINGS[:analytics_id]
      @view = klass::FLOW_STATE_MACHINE_SETTINGS[:view]

      current_session[@name] ||= {}
      @flow = flow.new(self, current_session, @name)
    end

    def render_update(step, result)
      redirect_to next_step and return if next_step_is_url
      move_to_next_step and return if result.success?
      ensure_correct_step and return
      set_error_and_render(step, result)
    end

    def set_error_and_render(step, result)
      flow_session = flow.flow_session
      flow_session[:error_message] = result.first_error_message
      render_step(step, flow_session)
    end

    def move_to_next_step
      current_session[@name] = flow.flow_session
      redirect_to_step(next_step)
    end

    def render_step(step, flow_session)
      @params = params
      @request = request
      return if call_optional_show_step(step)
      step_params = flow.extra_view_variables(step)
      local_params = step_params.merge(
        flow_namespace: @namespace,
        flow_session: flow_session,
        step_indicator: step_indicator_params,
        step_template: "#{@view || @name}/#{step}",
      )
      render template: 'layouts/flow_step', locals: local_params
    end

    def call_optional_show_step(optional_step)
      return unless @flow.class.const_defined?(:OPTIONAL_SHOW_STEPS)
      optional_show_step = @flow.class::OPTIONAL_SHOW_STEPS.with_indifferent_access[optional_step]
      return unless optional_show_step
      result = optional_show_step.new(@flow).base_call

      optional_show_step_name = optional_show_step.to_s.demodulize.underscore
      optional_properties = result.to_h.merge(
        step: optional_show_step_name,
        analytics_id: @analytics_id,
      )

      analytics.public_send(
        optional_show_step.analytics_optional_step_event,
        **optional_properties,
      )

      if next_step.to_s != optional_step
        if next_step_is_url
          redirect_to next_step
        else
          redirect_to_step(next_step)
        end
        return true
      end
      false
    end

    def step_indicator_params
      return if !flow.class.const_defined?(:STEP_INDICATOR_STEPS)
      handler = flow.step_handler(current_step)
      return if !handler || !handler.const_defined?(:STEP_INDICATOR_STEP)
      {
        steps: flow.class::STEP_INDICATOR_STEPS,
        current_step: handler::STEP_INDICATOR_STEP,
      }
    end

    def ensure_correct_step
      redirect_to_step(next_step) if next_step.to_s != current_step
    end

    def flow_finish
      redirect_to send(@final_url)
    end

    def redirect_to_step(step)
      flow_finish and return unless next_step
      redirect_to send(@step_url, step: step)
    end

    def analytics_properties
      {
        flow_path: @flow.flow_path,
        step: current_step,
        step_count: current_flow_step_counts[current_step_name],
        analytics_id: @analytics_id,
        irs_reproofing: current_user&.decorate&.reproof_for_irs?(
          service_provider: current_sp,
        ).present?,
      }
    end

    def current_step_name
      "#{current_step}_#{action_name}"
    end

    def current_flow_step_counts
      current_session["#{@name}_flow_step_counts"] ||= {}
      current_session["#{@name}_flow_step_counts"].default = 0
      current_session["#{@name}_flow_step_counts"]
    end

    def increment_step_name_counts
      current_flow_step_counts[current_step_name] += 1
    end

    def next_step
      flow.next_step
    end

    def next_step_is_url
      next_step.to_s.index(':')
    end

    def current_session
      user_session || session
    end
  end
end

# sample usage:
#
# class FooController
#   include Flow::FlowStateMachine
#
#   FLOW_STATE_MACHINE_SETTINGS = {
#     step_url: :foo_step_url,
#     final_url: :after_foo_url,
#     flow: FooFlow,
#     analytics_id: Analytics::FOO,
#   }.freeze
# end
