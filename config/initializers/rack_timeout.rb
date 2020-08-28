module Rack
  class Timeout
    @excludes = [
      '/verify/doc_auth/front_image',
      '/verify/doc_auth/back_image',
      '/verify/doc_auth/mobile_front_image',
      '/verify/doc_auth/mobile_back_image',
      '/verify/doc_auth/selfie',
      '/verify/doc_auth/document_capture',
      '/verify/doc_auth/verify',
      '/verify/capture_doc/mobile_front_image',
      '/verify/capture_doc/capture_mobile_back_image',
      '/verify/capture_doc/selfie',
      '/verify/capture_doc/document_capture',
      '/verify/recovery/front_image',
      '/verify/recovery/back_image',
      '/verify/recovery/mobile_front_image',
      '/verify/recovery/mobile_back_image',
      '/verify/recovery/verify',
      '/verify/doc_auth/link_sent',
    ]

    class << self
      attr_accessor :excludes
    end

    def call_with_excludes(env)
      if self.class.excludes.any? { |exclude_uri| /\A#{exclude_uri}/ =~ env['REQUEST_URI'] }
        @app.call(env)
      else
        call_without_excludes(env)
      end
    end

    alias call_without_excludes call
    alias call call_with_excludes
  end
end

if Rails.env.development?
  Rails.logger.info 'Disabling Rack::Timeout Logging'
  Rack::Timeout::Logger.disable
end
