class GoogleAnalyticsMeasurement
  GA_HOST = 'www.google-analytics.com/'.freeze
  GA_COLLECT_ENDPOINT = '/collect'.freeze

  cattr_accessor :adapter do
    Faraday.new(url: GA_HOST) do |faraday|
    faraday.adapter :typhoeus
    end
  end

  def initialize(category:, event_action:, method:, client_id:)
      @category = category
      @event_action = event_action
      @method = method
      @client_id = client_id
  end

  private

      attr_reader :category, :event_action, :method, :client_id

      def response
          @response ||= begin
          adapter.post do |request|
              request.url GA_VERIFY_ENDPOINT
              request.body = request_body
          end
          end
      end

      def request_body
          {
              v: 1,
              tid: Figaro.env.ga_uid,
              t: 'event',
              c: :category,
              ea: :event_action,
              el: :method
          }
      end
end
