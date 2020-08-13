class GoogleAnalyticsMeasurement
  GA_URL = 'https://www.google-analytics.com/collect'.freeze
  TIMEOUT = Figaro.env.google_analytics_timeout.to_i

  attr_reader :category, :event_action, :method, :client_id

  cattr_accessor :adapter do
    Faraday.new(url: GA_URL, request: { open_timeout: TIMEOUT, timeout: TIMEOUT }) do |faraday|
      faraday.adapter :typhoeus
    end
  end

  def initialize(category:, event_action:, method:, client_id:)
    @category = category
    @event_action = event_action
    @method = method
    @client_id = client_id
  end

  def send_event
    adapter.post do |request|
      request.body = request_body
    end
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => err
    Rails.logger.error("#{self.class.name} post error: #{err.message}")
  end

  private

  def request_body
    {
      v: 1,
      tid: Figaro.env.google_analytics_key,
      t: :event,
      ec: category,
      ea: event_action,
      el: method,
      cid: client_id,
    }
  end
end
