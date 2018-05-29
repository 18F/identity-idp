require 'utf8_cleaner'

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
      return if FeatureManagement.use_dashboard_service_providers?
      # Ahoy visitor_token and visit_token are read from request headers
      # and cookies, and pentesters often send cURL requests with
      # bogus token values. We want to exclude events where tokens are
      # invalid UUIDs.
      super || invalid_uuid?(ahoy.visitor_token) || invalid_uuid?(ahoy.visit_token)
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

    def invalid_uuid?(token)
      # The match? method does not exist for the Regexp class in Ruby < 2.4
      # Here, it comes from Active Support. Once we upgrade to Ruby 2.5,
      # we probably want to ignore the Rails definition and use Ruby's.
      # To do that, we'll need to set `config.active_support.bare = true`,
      # and then only require the extensions we use.
      token = Utf8Cleaner.new(token).remove_invalid_utf8_bytes
      uuid_regex = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      !uuid_regex.match?(token)
    end
  end
end
