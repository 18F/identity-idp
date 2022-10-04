class IrsAttemptEventsBatchJob < ApplicationJob

  require 'tempfile'

  # copypasta
  include JobHelpers::StaleJobHelper
  queue_as :default
  discard_on JobHelpers::StaleJobHelper::StaleJobError

  # Get this to run at the early part of the hour
  
  def perform(subject_timestamp)
    puts 'Howdy, partner'

    # Probably want something more durable
    # mktmpdir won't auto-delete if it's not called with a block:
    # https://ruby-doc.org/stdlib-2.5.1/libdoc/tmpdir/rdoc/Dir.html
    dir = Dir.mktmpdir(subject_timestamp.to_s)
    file = File.new("#{dir}/#{Time.now.to_fs(:number)}", 'w')

    events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: subject_timestamp)
    events.each do |event|
      file.write event
    end
    file.close
    file.path
  end

  private

end
