# frozen_string_literal: true

class AbTest
  include ::NewRelic::Agent::MethodTracer

  attr_reader :buckets, :experiment_name, :default_bucket, :should_log, :report

  MAX_SHA = (16 ** 64) - 1

  # @param [Proc<String>,Regexp,string,Boolean,nil] should_log Controls whether bucket data for this
  #                                                            A/B test is logged with specific
  #                                                            events.
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
    &discriminator
  )
    @buckets = buckets
    @discriminator = discriminator
    @experiment_name = experiment_name
    @default_bucket = default_bucket
    @should_log = should_log
    @report = report
    raise 'invalid bucket data structure' unless valid_bucket_data_structure?
    ensure_numeric_percentages
    raise 'bucket percentages exceed 100' unless within_100_percent?
  end

  # @param [ActionDispatch::Request] request
  # @param [String,nil] service_provider Issuer string for the service provider associated with
  #                                      the current session.
  # @param [Hash] session
  # @param [User] user
  # @param [Hash] user_session
  def bucket(request:, service_provider:, session:, user:, user_session:)
    return nil if !active?

    discriminator = resolve_discriminator(
      request:, service_provider:, session:, user:,
      user_session:
    )
    return nil if discriminator.blank?

    user_value = percent(discriminator)

    min = 0
    buckets.keys.each do |key|
      max = min + buckets[key]
      return key if user_value > min && user_value <= max
      min = max
    end

    @default_bucket
  end

  def include_in_analytics_event?(event_name)
    if should_log.is_a?(Regexp)
      should_log.match?(event_name)
    elsif should_log.respond_to?(:include?)
      should_log.include?(event_name)
    elsif !should_log.nil?
      raise 'Unexpected value used for should_log'
    else
      true
    end
  end

  def active?
    return @active if defined?(@active)
    @active = buckets.present? && buckets.values.any?(&:positive?)
  end

  private

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
