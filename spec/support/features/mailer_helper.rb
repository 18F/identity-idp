RSpec.configure do |config|
  config.before(:each, email: true) do
    ActionMailer::Base.deliveries = []
  end
end

module Features
  module MailerHelper
    def last_email
      ActionMailer::Base.deliveries.last
    end

    def reset_email
      ActionMailer::Base.deliveries = []
    end
  end
end
