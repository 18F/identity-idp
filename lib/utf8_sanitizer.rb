require 'rack_request_parser'
require 'utf8_cleaner'

class Utf8Sanitizer
  def initialize(app)
    @app = app
  end

  # :reek:DuplicateMethodCall
  # :reek:TooManyStatements
  def call(env)
    parser = RackRequestParser.new(Rack::Request.new(env))
    values_to_check = parser.values_to_check

    if invalid_strings(values_to_check)
      Rails.logger.info(invalid_utf8_event(env, parser.request))

      return [400, {}, ['Bad request']]
    end

    @app.call(env)
  rescue Rack::QueryParser::InvalidParameterError => err
    Rails.logger.info(invalid_parameter_event(err))
    [400, {}, ['Bad request']]
  end

  private

  def invalid_strings(values)
    string_values(values).any? { |string| invalid_string?(string) }
  end

  def string_values(values)
    values.select { |value| value.is_a?(String) }
  end

  def invalid_string?(string)
    !string.force_encoding('UTF-8').valid_encoding?
  end

  def invalid_utf8_event(env, request)
    {
      event: 'Invalid UTF-8 encoding',
      user_uuid: env['warden']&.user&.uuid || AnonymousUser.new.uuid,
      ip: remote_ip(request),
      user_agent: sanitized_user_agent(request),
      timestamp: Time.zone.now,
      hostname: sanitized_hostname(request),
      visitor_id: sanitized_visitor_id(request),
      content_type: env['CONTENT_TYPE'],
    }.to_json
  end

  def remote_ip(request)
    @remote_ip ||= (request.env['action_dispatch.remote_ip'] || request.ip).to_s
  end

  def sanitized_hostname(request)
    Utf8Cleaner.new(request.host).remove_invalid_utf8_bytes
  end

  def sanitized_user_agent(request)
    Utf8Cleaner.new(request.user_agent).remove_invalid_utf8_bytes
  end

  def sanitized_visitor_id(request)
    string_to_clean = request.cookies['ahoy_visitor']
    Utf8Cleaner.new(string_to_clean).remove_invalid_utf8_bytes
  end

  def invalid_parameter_event(error)
    {
      event: 'Invalid parameter error',
      message: error.message,
    }
  end
end
