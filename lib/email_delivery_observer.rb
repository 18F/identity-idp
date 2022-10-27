class EmailDeliveryObserver
  def self.delivered_email(mail)
    metadata = mail.instance_variable_get(:@_metadata) || {}
    user = metadata[:user] || AnonymousUser.new
    action = metadata[:action]
    Analytics.new(user: user, request: nil, sp: nil, session: {}).
      email_sent(action: action, ses_message_id: mail.header[:ses_message_id]&.value)
  end
end
