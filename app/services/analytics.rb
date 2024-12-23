# frozen_string_literal: true

class Analytics
  include AnalyticsEvents
  prepend Idv::AnalyticsEventsEnhancer

  # Analytics middleware that sends the event to Ahoy
  class AhoyMiddleware
    attr_reader :ahoy

    def initialize(ahoy: nil, request: nil)
      @ahoy = ahoy || Ahoy::Tracker.new(request:)
    end

    def call(event)
      ahoy.track(event[:name], event[:properties])
      nil
    end
  end

  # Analytics middleware that augments NewRelic APM trace with additional metadata.
  class NewRelicMiddleware
    def call(event)
      # Tag NewRelic APM trace with a handful of useful metadata
      # https://www.rubydoc.info/github/newrelic/rpm/NewRelic/Agent#add_custom_attributes-instance_method
      ::NewRelic::Agent.add_custom_attributes(
        user_id: event.dig(:properties, :user_id),
        user_ip: event.dig(:properties, :user_ip),
        service_provider: event.dig(:properties, :service_provider),
        event_name: event[:name],
        git_sha: IdentityConfig::GIT_SHA,
      )

      nil
    end
  end

  class << self
    # @return [Proc[]] The set of middleware Procs added to all new Analytics instances by default.
    def default_middleware
      @default_middleware ||= []
    end

    # @param [Proc[]] middlewares Middleware procs to add while block executes.
    # Added for use in specs only
    def with_default_middleware(*middlewares, &block)
      middlewares.each { |m| default_middleware << m }
      block.call
    ensure
      middlewares.each { |m| default_middleware.delete(m) }
    end
  end

  attr_reader :user, :request, :sp, :session
  attr_reader :middleware

  # @param [User] user
  # @param [ActionDispatch::Request,nil] request
  # @param [String,nil] sp Service provider issuer string.
  # @param [Hash] session
  # @param [Ahoy::Tracker,nil] ahoy
  def initialize(user:, request:, sp:, session:, ahoy: nil)
    @user = user
    @request = request
    @sp = sp
    @session = session
    @middleware = Analytics.default_middleware.dup

    middleware << AhoyMiddleware.new(ahoy:, request:)
    middleware << NewRelicMiddleware.new
  end

  def track_event(event, attributes = {})
    attributes.delete(:pii_like_keypaths)
    update_session_events_and_paths_visited_for_analytics(event) if attributes[:success] != false
    analytics_hash = {
      event_properties: attributes.except(:user_id).compact,
      new_event: first_event_this_session?,
      path: request&.path,
      service_provider: sp,
      session_duration: session_duration,
      user_id: attributes[:user_id] || user.uuid,
      locale: I18n.locale,
    }

    analytics_hash.merge!(request_attributes) if request
    analytics_hash.merge!(sp_request_attributes) if sp_request_attributes
    analytics_hash.merge!(ab_test_attributes(event))

    event_for_middleware = {
      name: event,
      properties: analytics_hash,
    }.freeze

    middleware.each do |m|
      potential_new_event = m.call(event_for_middleware)

      if potential_new_event.is_a?(Hash)
        event_for_middleware = result
      end
    end
  end

  def update_session_events_and_paths_visited_for_analytics(event)
    session[:events] ||= {}
    session[:first_event] = !@session[:events].key?(event)
    session[:events][event] = true
  end

  def first_event_this_session?
    session[:first_event]
  end

  def request_attributes
    attributes = {
      user_ip: request.remote_ip,
      hostname: request.host,
      pid: Process.pid,
      trace_id: request.headers['X-Amzn-Trace-Id'],
    }

    attributes[:git_sha] = IdentityConfig::GIT_SHA
    if IdentityConfig::GIT_TAG.present?
      attributes[:git_tag] = IdentityConfig::GIT_TAG
    else
      attributes[:git_branch] = IdentityConfig::GIT_BRANCH
    end

    attributes.merge!(browser_attributes)
  end

  def ab_test_attributes(event)
    user_session = session.dig('warden.user.user.session')
    ab_tests = AbTests.all.each_with_object({}) do |(test_id, test), obj|
      next if !test.include_in_analytics_event?(event)

      bucket = test.bucket(
        request:,
        service_provider: sp,
        session:,
        user:,
        user_session:,
      )
      if !bucket.blank?
        obj[test_id.downcase] = {
          bucket:,
        }
      end
    end

    ab_tests.empty? ?
      {} :
      {
        ab_tests: ab_tests,
      }
  end

  def browser
    @browser ||= BrowserCache.parse(request.user_agent)
  end

  def browser_attributes
    {
      user_agent: request.user_agent,
      browser_name: browser.name,
      browser_version: browser.full_version,
      browser_platform_name: browser.platform.name,
      browser_platform_version: browser.platform.version,
      browser_device_name: browser.device.name,
      browser_mobile: browser.device.mobile?,
      browser_bot: browser.bot?,
    }
  end

  def session_duration
    session[:session_started_at].present? ? Time.zone.now - session_started_at : nil
  end

  def session_started_at
    value = session[:session_started_at]
    return value unless value.is_a?(String)
    Time.zone.parse(value)
  end

  def sp_request_attributes
    resolved_result = resolved_authn_context_result
    return if resolved_result.nil?

    attributes = resolved_result.to_h
    attributes[:component_values] = resolved_result.component_values.map do |v|
      [v.name.sub("#{Saml::Idp::Constants::LEGACY_ACR_PREFIX}/", ''), true]
    end.to_h
    attributes[:component_names] = resolved_result.component_names
    attributes.reject! { |_key, value| value == false }

    if differentiator.present?
      attributes[:app_differentiator] = differentiator
    end

    attributes.transform_keys! do |key|
      key.to_s.chomp('?').to_sym
    end

    { sp_request: attributes }
  end

  def differentiator
    return @differentiator if defined?(@differentiator)
    @differentiator ||= begin
      sp_request_url = session&.dig(:sp, :request_url)
      return nil if sp_request_url.blank?

      UriService.params(sp_request_url)['login_gov_app_differentiator']
    end
  end

  def resolved_authn_context_result
    return nil if sp.blank? ||
                  session[:sp].blank? ||
                  (session[:sp][:vtr].blank? && session[:sp][:acr_values].blank?)
    return @resolved_authn_context_result if defined?(@resolved_authn_context_result)

    service_provider = ServiceProvider.find_by(issuer: sp)

    @resolved_authn_context_result = AuthnContextResolver.new(
      user: user,
      service_provider:,
      vtr: session[:sp][:vtr],
      acr_values: session[:sp][:acr_values],
    ).result
  rescue Vot::Parser::ParseException
    return
  end
end
