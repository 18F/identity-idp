module Flow
  module FlowStateMachine
    extend ActiveSupport::Concern

    included do
      before_action :fsm_initialize
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
      if @analytics_id
        increment_step_name_counts
        analytics.track_event(analytics_submitted, result.to_h.merge(analytics_properties))
        # keeping the old event names for backward compatibility
        analytics.track_event(old_analytics_submitted, result.to_h.merge(analytics_properties))
      end
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
      if @analytics_id
        increment_step_name_counts
        analytics.track_event(analytics_visited, analytics_properties)
        # keeping the old event names for backward compatibility
        analytics.track_event(old_analytics_visited, analytics_properties)
      end
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

    def fsm_initialize
      klass = self.class
      flow = klass::FSM_SETTINGS[:flow]
      @name = klass.name.underscore.gsub('_controller', '')
      @namespace = flow.name.split('::').first.underscore
      @step_url = klass::FSM_SETTINGS[:step_url]
      @final_url = klass::FSM_SETTINGS[:final_url]
      @analytics_id = klass::FSM_SETTINGS[:analytics_id]
      @view = klass::FSM_SETTINGS[:view]

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
      return unless @flow.class.const_defined?('OPTIONAL_SHOW_STEPS')
      optional_show_step = @flow.class::OPTIONAL_SHOW_STEPS.with_indifferent_access[optional_step]
      return unless optional_show_step
      result = optional_show_step.new(@flow).base_call

      if @analytics_id
        optional_show_step_name = optional_show_step.to_s.demodulize.underscore
        optional_properties = result.to_h.merge(step: optional_show_step_name)

        analytics.track_event(analytics_optional_step, optional_properties)
        # keeping the old event names for backward compatibility
        analytics.track_event(old_analytics_optional_step, optional_properties)
      end

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
      handler = flow.step_handler(current_step)
      return if !flow.class.const_defined?('STEP_INDICATOR_STEPS') || !handler
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

    def analytics_submitted
      'IdV: ' + "#{@analytics_id} #{current_step} submitted".downcase
    end

    def analytics_visited
      'IdV: ' + "#{@analytics_id} #{current_step} visited".downcase
    end

    def analytics_optional_step
      'IdV: ' + "#{@analytics_id} optional #{current_step} submitted".downcase
    end

    def old_analytics_submitted
      @analytics_id + ' submitted'
    end

    def old_analytics_visited
      @analytics_id + ' visited'
    end

    def old_analytics_optional_step
      [@analytics_id, 'optional submitted'].join(' ')
    end

    def analytics_properties
      {
        flow_path: @flow.flow_path,
        step: current_step,
        step_count: current_flow_step_counts[current_step_name],
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
#   FSM_SETTINGS = {
#     step_url: :foo_step_url,
#     final_url: :after_foo_url,
#     flow: FooFlow,
#     analytics_id: Analytics::FOO,
#   }.freeze
# end
