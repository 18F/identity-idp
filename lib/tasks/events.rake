# frozen_string_literal: true

namespace :events do
  desc 'Delete max_attempts_reached events by stored event type'
  task delete_max_attempts_reached: :environment do |_task, _args|
    batch_size = Integer(ENV.fetch('BATCH_SIZE', 1000), 10)
    target_event_type = 28
    target_events = Event.where(event_type: target_event_type)

    if target_events.exists?
      deleted_count = target_events.in_batches(of: batch_size).delete_all
      puts "Deleted #{deleted_count} events with event_type=#{target_event_type}."
    else
      warn "No events found with event_type=#{target_event_type}."
    end
  end
end
