# frozen_string_literal: true

module Idv
  class AamvaStateMaintenanceWindow
    # All AAMVA maintenance windows are expressed in 'ET' (LG-14028),
    TZ = 'America/New_York'

    MAINTENANCE_WINDOWS = {
      'AL' => [
        # First Monday of each month from 1 am – 7 am ET
        { cron: '0 1 * * Mon#1', duration_minutes: 6 * 60 },
      ],
      'CA' => [
        # Daily, 4:00 - 5:30 am. ET.
        { cron: '0 4 * * *', duration_minutes: 90 },
        # Monday, 1:00 - 1:45 am. ET
        { cron: '0 1 * * Mon', duration_minutes: 45 },
        # Monday, 1:00 - 4:30 am. ET on 1st and 3rd Monday of month.
        { cron: '0 1 * * Mon#1', duration_minutes: 3.5 * 60 },
        { cron: '0 1 * * Mon#3', duration_minutes: 3.5 * 60 },
      ],
      'CO' => [
        # 02:00 - 08:00 AM ET on the first Tuesday of every month.
        { cron: '0 2 * * Tue#1', duration_minutes: 6 * 60 },
      ],
      'CT' => [
        # Daily, 3:00 am. to 4:00 am. ET.
        { cron: '0 3 * * *', duration_minutes: 1 },
        # Sunday 5:00 am. to 7:00 am. ET
        { cron: '0 6 * * Sun', duration_minutes: 2 * 60 },
        # second Sunday of month 4:00 am. to 8:00 am. ET
        { cron: '0 4 * * Sun#2', duration_minutes: 4 * 60 }
      ],
      'DC' => [
        # Daily, Midnight to 6 am. ET.
        { cron: '0 0 * * *', duration_minutes: 6 * 60 },
      ],
      'DE' => [
        # Daily, Midnight to 5 am. ET.
        { cron: '0 0 * * *', duration_minutes: 5 * 60 },
      ],
      'FL' => [
        # Sunday 7:00 am. to 12:00 pm. ET
        { cron: '0 7 * * Sun', duration_minutes: 5 * 60 },
      ],
      'GA' => [
        # Daily, 5:00 am. to 6:00 am. ET.
        { cron: '0 5 * * *', duration_minutes: 60 },
      ],
      'IA' => [
        # "Daily, normally at 4:45 am. to 5:15 am ET."
        { cron: '45 4 * * *', duration_minutes: 30 },
        # (Also "Sunday mornings but only seconds at a time.")
      ],
      'ID' => [
        # "Every third Wednesday: 9:00 pm to midnight ET"
        # This is impossible to model as a cron expression, and it's
        # meaningless in English without identifying when it starts.
        # I'm modeling this as _every_ Wednesday since we're really
        # answering "Should we expect a maintenance window right now?",
        # and we don't block the user from anything.
        { cron: '0 21 * * Wed', duration_minutes: 3 * 60 },
      ],
      'IL' => [
        # Daily, 2:30 am. to 5:00 am. ET.
        { cron: '30 2 * * *', duration_minutes: 2.5 * 60 },
      ],
      'IN' => [
        # Sunday 5:00 am. to 10:00 am. ET.
        { cron: '0 5 * * Sun', duration_minutes: 5 * 60 },
      ],
      'KS' => [
        # Sunday: 7:00 am. to 1:00 pm. ET
        { cron: '0 7 * * Sun', duration_minutes: 6 * 60 },
      ],
      'KY' => [
        # Daily maintenance from 2:35 am. to 6:40 am. ET
        { cron: '35 2 * * *', duration_minutes: 245 },
        # "Monthly on Sunday, midnight to 10:00 am ET."
        # (Okay, but _which_ Sunday?)
      ],
      'MA' => [
        # Daily 3:00 am. to 4:00 am. ET.
        { cron: '0 3 * * *', duration_minutes: 60 },
        # Saturday 10:00 pm. to Sunday 10:00 am
        { cron: '0 22 * * Sat', duration_minutes: 12 * 60 },
        # Sunday 2:00 am to 5:00 am ET
        { cron: '0 2 * * Sun', duration_minutes: 3 * 60 },
        # First Friday of each month: 12 to 6 am. ET.
        { cron: '0 0 * * Fri#1', duration_minutes: 6 * 60 },
      ],
      'MD' => [
        # Sunday maintenance may occur from 6 am. to 10 am. ET.
        { cron: '0 6 * * Sun', duration_minutes: 4 * 60 },
      ],
      'MI' => [
        # Daily maintenance from 9 pm. to 9:30 pm. ET.
        { cron: '0 21 * * *', duration_minutes: 30 },
      ],
      'MO' => [
        # Daily maintenance from 2 am. to 4:30 am. ...
        { cron: '0 2 * * *', duration_minutes: 2.5 * 60 },
        # ... from 6:30 am to 6:45 am ...
        { cron: '30 6 * * *', duration_minutes: 15 },
        # ... and 8:30 am. to 8:35 am ET.
        { cron: '30 8 * * *', duration_minutes: 5 },
      ],
      'MT' => [
        # Third Saturday of odd numbered months from 12:00 am to 6:00 am ET
        # MW FIXME: I need to test if this is valid, or if the month has to be 1,3,5,7,9,11
        { cron: '0 2 * /2 Sat#3', duration_minutes: 6 * 60 },
      ],
      'NC' => [
        # Daily, Midnight to 7:00 am. ET.
        { cron: '0 0 * * *', duration_minutes: 7 * 60 },
      ],
      'ND' => [
        # Wednesday around 7:30 pm to 7:35 pm ET
        { cron: '30 19 * * Wed', duration_minutes: 5 },
        # 3rd Sunday of month, 5 minutes anytime between midnight and noon.
      ],
      'NM' => [
        # Sundays 8:00 am. to noon ET.
        { cron: '0 8 * * Sun', duration_minutes: 4 * 60 },
      ],
      'NV' => [
        # Tuesdays to Sundays: 2:00 am. to 3:15 am. ET
        # MW FIXME: This wraps around, does Tue-Sun get parsed correctly?
        { cron: '0 2 * * Tue-Sun', duration_minutes: 1.25 * 60 },
      ],
      'NY' => [
        # Sunday maintenance 8 pm. to 9 pm. ET.
        { cron: '0 20 * * Sun', duration_minutes: 60 },
      ],
      'OH' => [
        # Daily 4:00 am. to 4:30 am. ET
        { cron: '0 4 * * *', duration_minutes: 30 },
      ],
      'OR' => [
        # Sunday 7:30 am. to 9:00 am. ET.
        { cron: '30 7 * * Sun', duration_minutes: 1.5 * 60 },
      ],
      'PA' => [
        # Sunday 5:00 am. to 7:00 am. ET.
        { cron: '0 5 * * Sun', duration_minutes: 2 * 60 },
      ],
      'RI' => [
        # Either 3rd or 4th Sunday of each month, 7:30 am. to 10:00 am. ET.
        { cron: '30 7 * * Sun#3', duration_minutes: 2.5 * 60 },
        { cron: '30 7 * * Sun#4', duration_minutes: 2.5 * 60 },
      ],
      'SC' => [
        # Sunday 6:00 pm. to 10:00 pm. ET.
        { cron: '0 18 * * Sun', duration_minutes: 4 * 60 },
      ],
      'TN' => [
        # Last Sunday of every month from 11:00 pm Sunday to 2:00 am. Monday ET
        { cron: '0 23 * * Sun#4', duration: 3 * 60 },
        { cron: '0 23 * * Sun#5', duration: 3 * 60 },
      ],
      'TX' => [
        # Saturday 9:00 pm. to Sunday 7:00 am. ET.
        { cron: '0 21 * * Sat', duration_minutes: 10 * 60 },
      ],
      'UT' => [
        # 3rd Sunday of every month 1:00 am. to 9:00 am. ET
        { cron: '0 1 0 0 Sun#3', duration_minutes: 8 * 60 },
      ],
      'VA' => [
        # Daily 5:00 am. to 5:30 am. ET
        { cron: '0 5 * * *', duration_minutes: 30 },
        # Sunday morning maintenance 3:00 am. to 5 am. ET.
        { cron: '0 3 * * Sun', duration_minutes: 2 * 60 },
        # "Might not respond for short spells, daily between 7 pm and 8:30 pm." (not modeling this)
      ],
      'VT' => [
        # Daily maintenance from midnight to 5 am. ET.
        { cron: '0 0 * * *', duration_minutes: 5 * 60 },
      ],
      'WA' => [
        # Maintenance from Saturday 9:45 pm. to Sunday 8:15 am. ET.
        { cron: '45 21 * * Sat', duration_minutes: 10.5 * 60 },
      ],
      'WI' => [
        # Downtime on Tuesday – Saturday typically between 3 – 4 am ET.
        { cron: '0 3 * * Tue-Sat', duration_minutes: 60 },
        # Downtime on Sunday from 6 – 10 am. ET.
        { cron: '0 6 * * Sun', duration_minutes: 4 * 60 },
      ],
      'WV' => [
        # Sunday 6:00 am. to 6:20 am. ET
        { cron: '0 6 * * Sun', duration_minutes: 20 },
      ],
      'WY' => [
        # Daily, 2 am. to 5 am. ET.
        { cron: '0 2 * * *', duration_minutes: 3 * 60 },
      ],
    }.freeze

    PARSED_MAINTENANCE_WINDOWS = MAINTENANCE_WINDOWS.transform_values do |windows|
      Time.use_zone(TZ) do
        windows.map do |window|
          cron = Fugit.parse_cron(window[:cron])
          { cron: cron, duration_minutes: window[:duration_minutes] }
        end
      end
    end.freeze

    class << self
      def in_maintenance_window?(state)
        Time.use_zone(TZ) do
          windows_for_state(state).any? { |window| window.cover?(Time.zone.now) }
        end
      end

      def windows_for_state(state)
        Time.use_zone(TZ) do
          PARSED_MAINTENANCE_WINDOWS.fetch(state, []).map do |window|
            previous = window[:cron].previous_time.to_t
            (previous..(previous + window[:duration_minutes].minutes))
          end
        end
      end
    end
  end
end
