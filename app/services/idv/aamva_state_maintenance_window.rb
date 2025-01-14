# frozen_string_literal: true

module Idv
  class AamvaStateMaintenanceWindow
    # All AAMVA maintenance windows are expressed in 'ET' (LG-14028),
    # except Montana's which we converted here from MST to ET.
    TZ = 'America/New_York'

    MAINTENANCE_WINDOWS = {
      'CA' => [
        # Daily, 4:00 - 5:30 am. ET.
        { cron: '0 4 * * *', duration_minutes: 90 },
        # Monday, 1:00 - 1:45 am. ET
        { cron: '0 1 * * Mon', duration_minutes: 45 },
        # Monday, 1:00 - 4:30 am. ET on 1st and 3rd Monday of month.
        { cron: '0 1 * * Mon#1', duration_minutes: 3.5 * 60 },
        { cron: '0 1 * * Mon#3', duration_minutes: 3.5 * 60 },
      ],
      'CT' => [
        # Daily, 4:00 am. to 6:30 am. ET.
        { cron: '0 4 * * *', duration_minutes: 90 },
        # Sunday 6:00 am. to 9:30 am. ET
        { cron: '0 6 * * Mon', duration_minutes: 3.5 * 60 },
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
      'IA' => [
        # "Daily system resets, normally at 4:45 am. to 5:15 am ET."
        { cron: '45 4 * * *', duration_minutes: 30 },
      ],
      'IN' => [
        # Sunday morning maintenance from 6 am. to 10 am. ET.
        { cron: '0 6 * * Sun', duration_minutes: 4 * 60 },
      ],
      'IL' => [
        { cron: '30 2 * * *', duration_minutes: 2.5 * 60 }, # Daily, 2:30 am. to 5 am. ET.
      ],
      'KY' => [
        # Daily maintenance from 2:50 am. to 6:40 am. ET
        { cron: '50 2 * * *', duration_minutes: 230 },
      ],
      'MA' => [
        # Daily maintenance from 6 am. to 6:15 am. ET.
        { cron: '0 6 * * *', duration_minutes: 15 },
        # Wednesday 7 am. to 7:30 am. ET.
        { cron: '0 7 * * Wed', duration_minutes: 30 },
        # Saturday 10:00 pm. to Sunday 10:00 am
        { cron: '0 22 * * Sat', duration_minutes: 12 * 60 },
        # First Friday of each month: 12 to 6 am. ET.
        { cron: '0 0 * * Fri#1', duration_minutes: 6 * 60 },
      ],
      'MD' => [
        # Daily maintenance from 3 am. to 3:15 am. ET.
        { cron: '0 3 * * *', duration_minutes: 15 },
        # Sunday maintenance may occur from 6 am. to 10 am. ET.
        { cron: '0 6 * * Sun', duration_minutes: 4 * 60 },
      ],
      'MI' => [
        # Daily maintenance from 9 pm. to 9:15 pm. ET.
        { cron: '0 21 * * *', duration_minutes: 15 },
      ],
      'MO' => [
        # Daily maintenance from 2 am. to 4:30 am. ...
        { cron: '0 2 * * *', duration_minutes: 2.5 * 60 },
        # ... from 6:30 am to 6:45 am ...
        { cron: '30 6 * * *', duration_minutes: 15 },
        # ... and 8:30 am. to 8:35 am ET.
        { cron: '30 8 * * *', duration_minutes: 5 },
        #  Sundays from 9 am. to 10:30 am. ET...
        { cron: '0 9 * * Sun', duration_minutes: 90 },
        # ...and 5 am to 5:45 am ET on 2nd Sunday of month.
        { cron: '0 5 * * Sun#2', duration_minutes: 45 },
      ],
      'MT' => [
        # Monthly maintenance occurs first Sunday of each month
        # from 12:00 am to 6:00 am (Mountain Time zone).
        { cron: '0 2 * * Sun#1', duration_minutes: 6 * 60 },
      ],
      'NC' => [
        # Daily, Midnight to 7:00 am. ET.
        { cron: '0 0 * * *', duration_minutes: 7 * 60 },
        # Sundays from 5am. till Noon
        { cron: '0 5 * * Sun', duration_minutes: 7 * 60 },
      ],
      # NM: "Sunday mornings." (not modeling; too vague)
      'NY' => [
        # Sunday maintenance 8 pm. to 9 pm. ET.
        { cron: '0 20 * * Sun', duration_minutes: 60 },
      ],
      'PA' => [
        # Sunday maintenance may occur, often between 5:30 am. & 7:00 am. ET
        { cron: '30 5 * * Sun', duration_minutes: 90 },
      ],
      'SC' => [
        # Sunday maintenance from 7:00 pm. to 10:00 pm. ET.
        { cron: '0 19 * * Sun', duration_minutes: 3 * 60 },
      ],
      'TX' => [
        # Downtime on weekends between 9 pm ET to 7 am ET.
        { cron: '0 21 * * Sat,Sun', duration_minutes: 10 * 60 },
      ],
      'VA' => [
        # Sunday morning maintenance 3:00 am. to 5 am. ET.
        { cron: '0 3 * * Sun', duration_minutes: 120 },
        # Daily maintenance from 5 am. to 5:30 am.
        { cron: '0 5 * * *', duration_minutes: 30 },
        # "Might not respond for short spells, daily between 7 pm  and 8:30 pm." (not modeling this)
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
        # Occasional Sunday maintenance from 6:00 am. to noon ET.
        { cron: '0 6 * * Sun', duration_minutes: 6 * 60 },
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
