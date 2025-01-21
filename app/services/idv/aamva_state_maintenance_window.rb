# frozen_string_literal: true

module Idv
  class AamvaStateMaintenanceWindow
    # All AAMVA maintenance windows are expressed in 'ET' (LG-14028),
    TZ = 'America/New_York'

    Window = Data.define(:cron, :duration) do
      def initialize(cron:, duration:)
        super(
          cron: Time.use_zone(TZ) { Fugit.parse_cron(cron) },
          duration:,
        )
      end
    end.freeze

    MAINTENANCE_WINDOWS = {
      'AL' => [
        # First Monday of each month from 1 am – 7 am ET
        Window.new(cron: '0 1 * * Mon#1', duration: 6.hours),
      ],
      'CA' => [
        # Daily, 4:00 - 5:30 am. ET.
        Window.new(cron: '0 4 * * *', duration: 90.minutes),
        # Monday, 1:00 - 1:45 am. ET
        Window.new(cron: '0 1 * * Mon', duration: 45.minutes),
        # Monday, 1:00 - 4:30 am. ET on 1st and 3rd Monday of month.
        Window.new(cron: '0 1 * * Mon#1', duration: 3.5.hours),
        Window.new(cron: '0 1 * * Mon#3', duration: 3.5.hours),
      ],
      'CO' => [
        # 02:00 - 08:00 AM ET on the first Tuesday of every month.
        Window.new(cron: '0 2 * * Tue#1', duration: 6.hours),
      ],
      'CT' => [
        # Daily, 3:00 am. to 4:00 am. ET.
        Window.new(cron: '0 3 * * *', duration: 1.hour),
        # Sunday 5:00 am. to 7:00 am. ET
        Window.new(cron: '0 6 * * Sun', duration: 2.hours),
        # second Sunday of month 4:00 am. to 8:00 am. ET
        Window.new(cron: '0 4 * * Sun#2', duration: 4.hours),
      ],
      'DC' => [
        # Daily, Midnight to 6 am. ET.
        Window.new(cron: '0 0 * * *', duration: 6.hours),
      ],
      'DE' => [
        # Daily, Midnight to 5 am. ET.
        Window.new(cron: '0 0 * * *', duration: 5.hours),
      ],
      'FL' => [
        # Sunday 7:00 am. to 12:00 pm. ET
        Window.new(cron: '0 7 * * Sun', duration: 5.hours),
      ],
      'GA' => [
        # Daily, 5:00 am. to 6:00 am. ET.
        Window.new(cron: '0 5 * * *', duration: 1.hour),
      ],
      'IA' => [
        # "Daily, normally at 4:45 am. to 5:15 am ET."
        Window.new(cron: '45 4 * * *', duration: 30.minutes),
        # (Also "Sunday mornings but only seconds at a time.")
      ],
      'ID' => [
        # "Every third Wednesday: 9:00 pm to midnight ET"
        # This is impossible to model as a cron expression, and it's
        # meaningless in English without identifying when it starts.
        # I'm modeling this as _every_ Wednesday since we're really
        # answering "Should we expect a maintenance window right now?",
        # and we don't block the user from anything.
        Window.new(cron: '0 21 * * Wed', duration: 3.hours),
      ],
      'IL' => [
        # Daily, 2:30 am. to 5:00 am. ET.
        Window.new(cron: '30 2 * * *', duration: 2.5.hours),
      ],
      'IN' => [
        # Sunday 5:00 am. to 10:00 am. ET.
        Window.new(cron: '0 5 * * Sun', duration: 5.hours),
      ],
      'KS' => [
        # Sunday: 7:00 am. to 1:00 pm. ET
        Window.new(cron: '0 7 * * Sun', duration: 6.hours),
      ],
      'KY' => [
        # Daily maintenance from 2:35 am. to 6:40 am. ET
        Window.new(cron: '35 2 * * *', duration: 245.minutes),
        # "Monthly on Sunday, midnight to 10:00 am ET."
        # (Okay, but _which_ Sunday?)
      ],
      'MA' => [
        # Daily 3:00 am. to 4:00 am. ET.
        Window.new(cron: '0 3 * * *', duration: 1.hour),
        # Saturday 10:00 pm. to Sunday 10:00 am
        Window.new(cron: '0 22 * * Sat', duration: 12.hours),
        # Sunday 2:00 am to 5:00 am ET
        Window.new(cron: '0 2 * * Sun', duration: 3.hours),
        # First Friday of each month: 12 to 6 am. ET.
        Window.new(cron: '0 0 * * Fri#1', duration: 6.hours),
      ],
      'MD' => [
        # Sunday maintenance may occur from 6 am. to 10 am. ET.
        Window.new(cron: '0 6 * * Sun', duration: 4.hours),
      ],
      'MI' => [
        # Daily maintenance from 9 pm. to 9:30 pm. ET.
        Window.new(cron: '0 21 * * *', duration: 30.minutes),
      ],
      'MO' => [
        # Daily maintenance from 2 am. to 4:30 am. ...
        Window.new(cron: '0 2 * * *', duration: 2.5.hours),
        # ... from 6:30 am to 6:45 am ...
        Window.new(cron: '30 6 * * *', duration: 15.minutes),
        # ... and 8:30 am. to 8:35 am ET.
        Window.new(cron: '30 8 * * *', duration: 5.minutes),
      ],
      'MT' => [
        # Third Saturday of odd numbered months from 12:00 am to 6:00 am ET
        Window.new(cron: '0 2 * /2 Sat#3', duration: 6.hours),
      ],
      'NC' => [
        # Daily, Midnight to 7:00 am. ET.
        Window.new(cron: '0 0 * * *', duration: 7.hours),
      ],
      'ND' => [
        # Wednesday around 7:30 pm to 7:35 pm ET
        Window.new(cron: '30 19 * * Wed', duration: 5.minutes),
        # 3rd Sunday of month, 5 minutes anytime between midnight and noon.
      ],
      'NM' => [
        # Sundays 8:00 am. to noon ET.
        Window.new(cron: '0 8 * * Sun', duration: 4.hours),
      ],
      'NV' => [
        # Tuesdays to Sundays: 2:00 am. to 3:15 am. ET
        Window.new(cron: '0 2 * * Tue-Sun', duration: 1.25.hours),
      ],
      'NY' => [
        # Sunday maintenance 8 pm. to 9 pm. ET.
        Window.new(cron: '0 20 * * Sun', duration: 1.hour),
      ],
      'OH' => [
        # Daily 4:00 am. to 4:30 am. ET
        Window.new(cron: '0 4 * * *', duration: 30.minutes),
      ],
      'OR' => [
        # Sunday 7:30 am. to 9:00 am. ET.
        Window.new(cron: '30 7 * * Sun', duration: 1.5.hours),
      ],
      'PA' => [
        # Sunday 5:00 am. to 7:00 am. ET.
        Window.new(cron: '0 5 * * Sun', duration: 2.hours),
      ],
      'RI' => [
        # Either 3rd or 4th Sunday of each month, 7:30 am. to 10:00 am. ET.
        Window.new(cron: '30 7 * * Sun#3', duration: 2.5.hours),
        Window.new(cron: '30 7 * * Sun#4', duration: 2.5.hours),
      ],
      'SC' => [
        # Sunday 6:00 pm. to 10:00 pm. ET.
        Window.new(cron: '0 18 * * Sun', duration: 4.hours),
      ],
      'TN' => [
        # Last Sunday of every month from 11:00 pm Sunday to 2:00 am. Monday ET
        Window.new(cron: '0 23 * * Sun#last', duration: 3.hours),
      ],
      'TX' => [
        # Saturday 9:00 pm. to Sunday 7:00 am. ET.
        Window.new(cron: '0 21 * * Sat', duration: 10.hours),
      ],
      'UT' => [
        # 3rd Sunday of every month 1:00 am. to 9:00 am. ET
        Window.new(cron: '0 1 * * Sun#3', duration: 8.hours),
      ],
      'VA' => [
        # Daily 5:00 am. to 5:30 am. ET
        Window.new(cron: '0 5 * * *', duration: 30.minutes),
        # Sunday morning maintenance 3:00 am. to 5 am. ET.
        Window.new(cron: '0 3 * * Sun', duration: 2.hours),
        # "Might not respond for short spells, daily between 7 pm and 8:30 pm." (not modeling this)
      ],
      'VT' => [
        # Daily maintenance from midnight to 5 am. ET.
        Window.new(cron: '0 0 * * *', duration: 5.hours),
      ],
      'WA' => [
        # Maintenance from Saturday 9:45 pm. to Sunday 8:15 am. ET.
        Window.new(cron: '45 21 * * Sat', duration: 10.5.hours),
      ],
      'WI' => [
        # Downtime on Tuesday – Saturday typically between 3 – 4 am ET.
        Window.new(cron: '0 3 * * Tue-Sat', duration: 1.hour),
        # Downtime on Sunday from 6 – 10 am. ET.
        Window.new(cron: '0 6 * * Sun', duration: 4.hours),
      ],
      'WV' => [
        # Sunday 6:00 am. to 6:20 am. ET
        Window.new(cron: '0 6 * * Sun', duration: 20.minutes),
      ],
      'WY' => [
        # Daily, 2 am. to 5 am. ET.
        Window.new(cron: '0 2 * * *', duration: 3.hours),
      ],
    }.freeze

    class << self
      def in_maintenance_window?(state)
        Time.use_zone(TZ) do
          windows_for_state(state).any? { |window| window.cover?(Time.zone.now) }
        end
      end

      def windows_for_state(state)
        Time.use_zone(TZ) do
          MAINTENANCE_WINDOWS.fetch(state, []).map do |window|
            previous = window.cron.previous_time.to_t
            (previous..(previous + window.duration))
          end
        end
      end
    end
  end
end
