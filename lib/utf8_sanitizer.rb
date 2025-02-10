# frozen_string_literal: true

require 'rack_request_parser'
require 'utf8_cleaner'

class Utf8Sanitizer
  def initialize(app)
    @app = app
  end

  def call(env)
    parser = RackRequestParser.new(Rack::Request.new(env))

    if contains_invalid_strings?(parser.values_to_check) ||
       contains_null_byte?(parser.request.params)
      return bad_request_and_log(invalid_utf8_event(env, parser.request))
    end

    @app.call(env)
  rescue Rack::QueryParser::InvalidParameterError, Rack::QueryParser::ParameterTypeError => err
    bad_request_and_log(invalid_parameter_event(err))
  rescue EOFError => err
    bad_request_and_log(eof_error_event(err))
  end

  private

  def contains_null_byte?(param)
    case param
    when Hash
      param.any? { |key, value| contains_null_byte?(key) || contains_null_byte?(value) }
    when Array
      param.any? { |value| contains_null_byte?(value) }
    when String
      param.include?("\x00")
    end
  end

  def contains_invalid_strings?(values)
    string_values(values).any? { |string| invalid_string?(string) }
  end

  def string_values(values)
    values.select { |value| value.is_a?(String) }
  end

  def invalid_string?(string)
    string = string.dup if string.frozen?
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

  def eof_error_event(error)
    {
      event: 'EOF error',
      message: error.message,
    }
  end

  def bad_request_and_log(event)
    Rails.logger.info(event)
    [400, {}, ['Bad request']]
  end
end
