# frozen_string_literal: true

module WaitPeriodFormatter
  extend ActionView::Helpers::DateHelper

  def self.call(duration)
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time,
      current_time + duration,
      true,
      accumulate_on: duration > 3.days ? :days : :hours,
    )
  end
end
