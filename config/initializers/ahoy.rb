Ahoy.api = false
# Period of inactivity before a new visit is created
Ahoy.visit_duration = Figaro.env.session_timeout_in_minutes.to_i.minutes
Ahoy.server_side_visits = false
Ahoy.geocode = false

module Ahoy
  class Store < Ahoy::BaseStore
    def track_visit(data)
      log_visit(data)
    end

    def track_event(data)
      data[:id] = data.delete(:event_id)
      data[:visitor_id] = ahoy.visitor_token
      data[:visit_id] = data.delete(:visit_token)

      log_event(data)
    end

    def exclude?
      return if FeatureManagement.enable_load_testing_mode?
      super
    end

    protected

    def log_visit(data)
      visit_logger.info data.to_json
    end

    def log_event(data)
      event_logger.info data.to_json
    end

    def visit_logger
      @visit_logger ||= ActiveSupport::Logger.new(Rails.root.join('log', 'visits.log'))
    end

    def event_logger
      @event_logger ||= ActiveSupport::Logger.new(Rails.root.join('log', 'events.log'))
    end
  end
end
