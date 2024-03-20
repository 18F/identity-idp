# frozen_string_literal: true

class Analytics
  include AnalyticsEvents
  prepend Idv::AnalyticsEventsEnhancer

  attr_reader :user, :request, :sp, :session, :ahoy

  def initialize(user:, request:, sp:, session:, ahoy: nil)
    @user = user
    @request = request
    @sp = sp
    @session = session
    @ahoy = ahoy || Ahoy::Tracker.new(request: request)
  end

  def track_event(event, attributes = {})
    attributes.delete(:pii_like_keypaths)
    update_session_events_and_paths_visited_for_analytics(event) if attributes[:success] != false
    analytics_hash = {
      event_properties: attributes.except(:user_id),
      new_event: first_event_this_session?,
      path: request&.path,
      session_duration: session_duration,
      user_id: attributes[:user_id] || user.uuid,
      locale: I18n.locale,
    }

    analytics_hash.merge!(request_attributes) if request
    analytics_hash.merge!(sp_request_attributes) if sp_request_attributes

    ahoy.track(event, analytics_hash)

    # Tag NewRelic APM trace with a handful of useful metadata
    # https://www.rubydoc.info/github/newrelic/rpm/NewRelic/Agent#add_custom_attributes-instance_method
    ::NewRelic::Agent.add_custom_attributes(
      user_id: analytics_hash[:user_id],
      user_ip: request&.remote_ip,
      service_provider: sp,
      event_name: event,
      git_sha: IdentityConfig::GIT_SHA,
    )
  end

  def update_session_events_and_paths_visited_for_analytics(event)
    session[:events] ||= {}
    session[:first_event] = !@session[:events].key?(event)
    session[:events][event] = true
  end

  def first_event_this_session?
    session[:first_event]
  end

  def track_mfa_submit_event(attributes)
    multi_factor_auth(
      **attributes,
      pii_like_keypaths: [[:errors, :personal_key], [:error_details, :personal_key]],
    )
  end

  def request_attributes
    attributes = {
      user_ip: request.remote_ip,
      hostname: request.host,
      pid: Process.pid,
      service_provider: sp,
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
      [v.name.sub('http://idmanagement.gov/ns/assurance/', ''), true]
    end.to_h
    attributes.reject! { |_key, value| value == false }
    attributes.transform_keys! do |key|
      key.to_s.chomp('?').to_sym
    end

    { sp_request: attributes }
  end

  def resolved_authn_context_result
    return nil if sp.nil? || session[:sp].blank?
    return @resolved_authn_context_result if defined?(@resolved_authn_context_result)

    service_provider = ServiceProvider.find_by(issuer: sp)

    @resolved_authn_context_result = AuthnContextResolver.new(
      service_provider:,
      vtr: session[:sp][:vtr],
      acr_values: session[:sp][:acr_values],
    ).resolve
  rescue Vot::Parser::ParseException
    return
  end
end
