module BasicAuthUrl
  module_function

  def build(url, user: Identity::Hostdata.settings.basic_auth_user_name,
            password: Identity::Hostdata.settings.basic_auth_password)
    URI.parse(url).tap do |uri|
      uri.user = user.presence
      uri.password = password.presence
    end.to_s
  end
end
