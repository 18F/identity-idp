# frozen_string_literal: true

namespace :events do
  desc 'Remove references to the removed max_attempts_reached event type'
  task remove_max_attempts_reached_references: :environment do
    batch_size = Integer(ENV.fetch('BATCH_SIZE', 1000), 10)
    target_event_type = 28
    target_events = Event.where(event_type: target_event_type)

    unless target_events.exists?
      warn "No events found with event_type=#{target_event_type}."
      next
    end

    deleted_count = target_events.in_batches(of: batch_size).delete_all
    puts "Deleted #{deleted_count} #{'event'.pluralize(deleted_count)} with event_type=#{target_event_type}."
  end
end
