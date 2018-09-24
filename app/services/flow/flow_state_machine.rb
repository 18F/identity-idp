module Flow
  module FlowStateMachine
    extend ActiveSupport::Concern

    included do
      before_action :fsm_initialize
      before_action :ensure_correct_step, only: :show
    end

    attr_accessor :flow

    def index
      redirect_to_step(flow.next_step)
    end

    def show
      step = params[:step]
      analytics.track_event(analytics_visited, step: step) if @analytics_id
      render_step(step, flow.flow_session)
    end

    def update
      step = params[:step]
      result = flow.handle(step, params)
      analytics.track_event(analytics_submitted, result.to_h.merge(step: step)) if @analytics_id
      render_update(step, result)
    end

    private

    def fsm_initialize
      klass = self.class
      @name = klass.name.underscore.gsub('_controller', '')
      klass::FSM_SETTINGS.each { |key, value| instance_variable_set("@#{key}", value) }
      user_session[@name] ||= {}
      @flow = @flow.new(user_session, current_user, @name)
    end

    def render_update(step, result)
      flow_finish and return unless flow.next_step
      move_to_next_step and return if result.success?
      flow_session = flow.flow_session
      flow_session[:error_message] = result.errors.values.join(' ')
      render_step(step, flow_session)
    end

    def move_to_next_step
      user_session[@name] = flow.flow_session
      redirect_to_step(flow.next_step)
    end

    def render_step(step, flow_session)
      render template: "#{@name}/#{step}", locals: { flow_session: flow_session }
    end

    def ensure_correct_step
      next_step = flow.next_step
      redirect_to_step(next_step) if next_step.to_s != params[:step]
    end

    def flow_finish
      redirect_to send(@final_url)
    end

    def redirect_to_step(step)
      redirect_to send(@step_url, step: step)
    end

    def analytics_submitted
      @analytics_id + ' submitted'
    end

    def analytics_visited
      @analytics_id + ' visited'
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
