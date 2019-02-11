module Idv
  module Presenters
    class DocAuthPresenter
      def initialize(session, request, params)
        @session = session
        @request = request
        @params = params
      end

      def mobile?
        client = DeviceDetector.new(@request.user_agent)
        client.device_type != 'desktop'
      end
    end
  end
end
