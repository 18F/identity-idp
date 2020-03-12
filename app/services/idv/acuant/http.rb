module Idv
  module Acuant
    module Http
      extend ActiveSupport::Concern

      included do
        include HTTParty
      end

      def get(url, options, &block)
        handle_response(self.class.get(url, options), block)
      end

      def post(url, options, &block)
        handle_response(self.class.post(url, options), block)
      end

      private

      def handle_response(response, block)
        return [false, response.message] unless success?(response)
        handle_success(response, block)
      end

      def handle_success(response, block)
        body = response.body
        data = block ? block.call(body) : body
        [true, data]
      end

      def success?(response)
        response.code.between?(200, 299)
      end

      def accept_json
        { 'Accept' => 'application/json' }
      end

      def content_type_json
        { 'Content-Type' => 'application/json' }
      end

      def env
        Figaro.env
      end
    end
  end
end
