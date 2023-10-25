# frozen_string_literal: true

class CountdownComponent < BaseComponent
  attr_reader :expiration, :update_interval, :start_immediately, :tag_options

  MILLISECONDS_PER_SECOND = 1000

  def initialize(
    expiration:,
    update_interval: 1.second,
    start_immediately: true,
    **tag_options
  )
    @expiration = expiration
    @update_interval = update_interval
    @start_immediately = start_immediately
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-countdown',
      time_remaining,
      **tag_options,
      data: {
        expiration: expiration.iso8601,
        update_interval: update_interval_in_ms,
        start_immediately:,
      }.merge(tag_options[:data].to_h),
    )
  end

  def update_interval_in_ms
    update_interval.in_seconds * MILLISECONDS_PER_SECOND
  end

  def time_remaining
    distance_of_time_in_words(Time.zone.now, expiration, true)
  end
end
