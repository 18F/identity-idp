# frozen_string_literal: true

class AbTest
  include ::NewRelic::Agent::MethodTracer

  attr_reader :buckets,
              :experiment_name,
              :default_bucket,
              :should_log,
              :report,
              :persist,
              :max_participants

  alias_method :experiment, :experiment_name
  alias_method :persist?, :persist

  MAX_SHA = (16 ** 64) - 1

  ReportQueryConfig = Struct.new(:title, :query, :row_labels, keyword_init: true).freeze

  ReportConfig = Struct.new(:email, :queries, keyword_init: true) do
    def initialize(queries: [], **)
      super
      self.queries.map!(&ReportQueryConfig.method(:new))
    end
  end.freeze

  # @param [Regexp,#include?,nil] should_log A list of analytics event names for which the A/B test
  #   bucket assignment should be logged, or a regular expression pattern which is tested against an
  #   analytics event name when an event is being logged.
  # @yieldparam [ActionDispatch::Request] request
  # @yieldparam [String,nil] service_provider Issuer string for the service provider associated with
  #                                           the current session.
  # @yieldparam [User] user
  # @yieldparam [Hash] user_session
  def initialize(
    experiment_name:,
    buckets: {},
    should_log: nil,
    default_bucket: :default,
    report: nil,
    persist: false,
    max_participants: Float::INFINITY,
    &discriminator
  )
    @buckets = buckets
    @discriminator = discriminator
    @experiment_name = experiment_name
    @default_bucket = default_bucket
    @should_log = should_log
    @report = ReportConfig.new(**report.to_h) if report
    @persist = persist
    raise 'max_participants requires persist to be true' if max_participants.finite? && !persist?
    @max_participants = max_participants
    raise 'invalid bucket data structure' unless valid_bucket_data_structure?
    ensure_numeric_percentages
    raise 'bucket percentages exceed 100' unless within_100_percent?
    @active = buckets.present? && buckets.values.any?(&:positive?)
  end

  # @param [ActionDispatch::Request] request
  # @param [String,nil] service_provider Issuer string for the service provider associated with
  #                                      the current session.
  # @param [Hash] session
  # @param [User] user
  # @param [Hash] user_session
  # @param [Boolean] persisted_read_only Avoid new bucket assignment if test is configured to be
  # persisted but there is no persisted value.
  def bucket(
    request:,
    service_provider:,
    session:,
    user:,
    user_session:,
    persisted_read_only: false
  )
    return nil if !active?

    discriminator = resolve_discriminator(
      request:, service_provider:, session:, user:,
      user_session:
    )
    return nil if discriminator.blank?

    persisted_value = AbTestAssignment.bucket(experiment:, discriminator:) if persist?
    return persisted_value if persisted_value || (persist? && persisted_read_only)

    return nil if maxed?

    user_value = percent(discriminator)

    bucket = @default_bucket

    min = 0
    buckets.keys.each do |key|
      max = min + buckets[key]
      if user_value > min && user_value <= max
        bucket = key
        break
      end
      min = max
    end

    AbTestAssignment.create(experiment:, discriminator:, bucket:) if persist?

    bucket
  end

  def include_in_analytics_event?(event_name)
    if should_log.is_a?(Regexp)
      should_log.match?(event_name)
    elsif should_log.respond_to?(:include?)
      should_log.include?(event_name)
    elsif !should_log.nil?
      raise 'Unexpected value used for should_log'
    else
      false
    end
  end

  def active?
    @active
  end

  private

  def maxed?
    return false if !persist? || !max_participants.finite?
    AbTestAssignment.where(experiment:).count >= max_participants
  end

  def resolve_discriminator(user:, **)
    if @discriminator
      @discriminator.call(user:, **)
    elsif !user.is_a?(AnonymousUser)
      user&.uuid
    end
  end

  def percent(discriminator)
    Digest::SHA256.hexdigest("#{discriminator}:#{experiment_name}").to_i(16).to_f / MAX_SHA * 100
  end

  def valid_bucket_data_structure?
    return false if !buckets.is_a?(Hash)

    buckets.values.each { |v| Float(v) }

    true
  rescue ArgumentError
    false
  end

  def ensure_numeric_percentages
    buckets.keys.each do |key|
      buckets[key] = buckets[key].to_f if buckets[key].is_a?(String)
    end
  end

  def within_100_percent?
    valid_bucket_data_structure? && buckets.values.sum <= 100
  end

  add_method_tracer :bucket, "Custom/#{name}/bucket"
  add_method_tracer :percent, "Custom/#{name}/percent"
end
