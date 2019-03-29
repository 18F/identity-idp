class GoogleAnalyticsMeasurement
  GA_ENDPOINT = 'https://www.google-analytics.com/collect'.freeze

  attr_reader :category, :event_action, :method, :client_id

  cattr_accessor :adapter do
    Faraday.new(url: GA_ENDPOINT) do |faraday|
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
  end

  private

  def request_body
    {
      v: 1,
      tid: Figaro.env.ga_uid,
      t: :event,
      c: category,
      ea: event_action,
      el: method,
      cid: client_id,
    }
  end
end
