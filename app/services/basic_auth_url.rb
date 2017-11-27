module BasicAuthUrl
  module_function

  def build(url, user: Figaro.env.basic_auth_user_name, password: Figaro.env.basic_auth_password)
    URI.parse(url).tap do |uri|
      uri.user = user
      uri.password = password
    end.to_s
  end
end
