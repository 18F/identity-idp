# frozen_string_literal: true

require 'rack/timeout/base'

module Rack
  class Timeout
    EXCLUDES = [
      '/verify/verify_info',
      '/verify/phone',
      '/verify/document_capture',
      '/verify/link_sent',
    ].flat_map do |path|
      [path] + Idp::Constants::AVAILABLE_LOCALES.map { |locale| "/#{locale}#{path}" }
    end + ['/api/verify/images']

    class << self
      attr_accessor :excludes
    end

    def call_with_excludes(env)
      if EXCLUDES.any? { |path| env['REQUEST_URI']&.start_with?(path) }
        @app.call(env)
      else
        call_without_excludes(env)
      end
    end

    alias call_without_excludes call
    alias call call_with_excludes
  end
end

Rack::Timeout::Logger.level = Logger::ERROR

Rails.application.config.middleware.insert_before(
  Rack::Runtime,
  Rack::Timeout,
  service_timeout: IdentityConfig.store.rack_timeout_service_timeout_seconds,
)

if Rails.env.development?
  Rails.logger.info 'Disabling Rack::Timeout Logging'
  Rack::Timeout::Logger.disable
end
