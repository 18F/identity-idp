module ActionMailer
  class MessageDelivery
    def deliver_later
      deliver_now
    end
  end
end
