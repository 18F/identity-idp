# frozen_string_literal: true

require 'utf8_cleaner'

Ahoy.api = false
# Period of inactivity before a new visit is created
Ahoy.visit_duration = IdentityConfig.store.session_timeout_in_minutes.minutes
Ahoy.server_side_visits = false
Ahoy.geocode = false
Ahoy.user_agent_parser = :browser
Ahoy.track_bots = true

module Ahoy
  class Store < Ahoy::BaseStore
    EVENT_FILENAME = 'events.log'

    def track_visit(data)
      log_visit(data)
    end

    def track_event(data)
      data.delete(:user_id)
      data[:id] = data.delete(:event_id)
      data[:visitor_id] = ahoy.visitor_token
      data[:visit_id] = data.delete(:visit_token)
      data[:log_filename] = EVENT_FILENAME

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
      @visit_logger ||= if FeatureManagement.log_to_stdout?
                          ActiveSupport::Logger.new(STDOUT)
                        else
                          ActiveSupport::Logger.new(Rails.root.join('log', 'visits.log'))
                        end
    end

    def event_logger
      @event_logger ||= if FeatureManagement.log_to_stdout?
                          ActiveSupport::Logger.new(STDOUT)
                        else
                          ActiveSupport::Logger.new(Rails.root.join('log', EVENT_FILENAME))
                        end
    end

    def invalid_uuid?(token)
      token = Utf8Cleaner.new(token).remove_invalid_utf8_bytes
      !Idp::Constants::UUID_REGEX.match?(token)
    end
  end
end
