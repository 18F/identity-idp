module BasicAuthUrl
  module_function

  def build(url, user: ENV['SP_NAME'], password: ENV['SP_PASS'])
    URI.parse(url).tap do |uri|
      uri.user = user
      uri.password = password
    end.to_s
  end
end
