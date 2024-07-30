# frozen_string_literal: true

module Idv
  class AamvaStateMaintenanceWindow
    class << self
      def in_maintenance_window?(state)
        return false unless (window = window_for_state(state))

        Time.use_zone(window['tz']) do
          start_time = Time.parse("today #{window['start_time']}")
          end_time = Time.parse("today #{window['end_time']}")
          Time.zone.now > start_time && Time.zone.now < end_time
        end
      end

      private

      def window_for_state(state)
        IdentityConfig.store.aamva_state_daily_maintenance_windows[state]
      end
    end
  end
end
