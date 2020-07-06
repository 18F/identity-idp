require 'gmail'

class GmailHelper
  attr_reader :gmail

  def initialize(email, password)
    @gmail = Gmail.connect!(email, password)
  end

  def inbox_unread
    gmail.inbox.emails(:unread)
  end

  def inbox_clear
    inbox_unread.each do |email|
      email.read!
    end
    gmail.inbox.emails(:read).each(&:delete!)
  end
end
