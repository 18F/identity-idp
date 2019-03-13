require 'net/http'

class AccountResetLambda
  def initialize(url, auth_token)
    @url = url
    @auth_token = auth_token
  end

  def send_notifications
    Kernel.puts "Sending delayed account reset notifications to #{@url}"
    time = now
    results = post
    Kernel.puts "Response #{results.code} #{results.message}: #{results.body}"
    duration = now - time
    Kernel.puts "Completed in #{duration.round(2)} seconds"
  end

  private

  def post
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 60
    http.read_timeout = 300
    http.use_ssl = true if uri.scheme == 'https'
    req = Net::HTTP::Post.new(uri.path, 'X-API-AUTH-TOKEN' => @auth_token)
    http.request(req)
  end

  def uri
    @uri ||= URI.parse(@url)
  end

  def now
    # TimeZone extensions do not apply when running in the lambda environment
    Time.now.to_f # rubocop:disable Rails/TimeZone
  end
end

# This lambda is triggered by cloudwatch to run on a recurring basis.
# It is invoked with the following parameters:
# AccountResetLambda.new(ENV['LOGIN_GOV_URL'], ENV['X_API_AUTH_TOKEN']).send_notifications
