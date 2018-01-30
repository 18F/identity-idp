class Utf8Sanitizer
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    values = all_values(request.params)

    if invalid_strings(values)
      Rails.logger.info(event_attributes(env, request))

      return [400, {}, ['Bad request']]
    end

    @app.call(env)
  end

  private

  def all_values(hash)
    hash.values.flat_map { |value| value.is_a?(Hash) ? all_values(value) : [value] }
  end

  def invalid_strings(values)
    string_values(values).any? { |string| invalid_string?(string) }
  end

  def string_values(values)
    values.select { |value| value.is_a?(String) }
  end

  def invalid_string?(string)
    !string.force_encoding('UTF-8').valid_encoding?
  end

  def event_attributes(env, request)
    {
      event: 'Invalid UTF-8 encoding',
      user_uuid: env['warden']&.user&.uuid || AnonymousUser.new.uuid,
      ip: remote_ip(request),
      user_agent: request.user_agent,
      timestamp: Time.zone.now,
      host: request.host,
      visitor_id: request.cookies['ahoy_visitor'],
      content_type: env['CONTENT_TYPE'],
    }.to_json
  end

  def remote_ip(request)
    @remote_ip ||= (request.env['action_dispatch.remote_ip'] || request.ip).to_s
  end
end
