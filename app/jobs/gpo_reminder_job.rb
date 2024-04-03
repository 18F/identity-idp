# frozen_string_literal: true

class GpoReminderJob < ApplicationJob
  queue_as :low

  # Send email reminders to people with USPS proofing letters whose
  # letters were sent a while ago, and haven't yet entered their code
  def perform(cutoff_time_for_sending_reminders)
    GpoReminderSender.new.
      send_emails(cutoff_time_for_sending_reminders)
  end
end
