module BasicAuthUrl
  module_function

  def build(url, user: AppConfig.env.basic_auth_user_name,
            password: AppConfig.env.basic_auth_password)
    URI.parse(url).tap do |uri|
      uri.user = user.presence
      uri.password = password.presence
    end.to_s
  end
end
