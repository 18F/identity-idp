# :reek:InstanceVariableAssumption
module Rack
  class Timeout
    @excludes = [
      '/verify/doc_auth/back_image',
      '/verify/doc_auth/mobile_back_image',
      '/verify/capture_doc/capture_mobile_back_image',
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
