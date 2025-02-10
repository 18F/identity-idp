module UserAgentHelper
  def desktop_user_agent
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) ' \
      'Chrome/58.0.3029.110 Safari/537.36'
  end

  def mobile_user_agent
    'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) \
AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1'
  end
end
