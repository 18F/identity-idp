#
# usage:
#   % rake check_stale_sessions [DEBUG=1] [PURGE=1]
#
desc 'check for stale sessions'
task check_stale_sessions: :environment do
  puts "now:               #{Time.zone.now}" if debug
  puts "stale_window_time: #{stale_window_time}" if debug
  ActiveRecord::SessionStore::Session.where('updated_at < ?', stale_window_time).each do |session|
    next unless session.data.keys.any?
    puts "pinged_at:         #{session.data[:pinged_at]}" if debug
    puts session.data.pretty_inspect if debug
    if stale?(session.data)
      puts " ----------> stale!" if debug
      session.destroy! if purge
    end
  end
end

def purge
  ENV['PURGE'] == '1'
end

def debug
  ENV['DEBUG'] == '1'
end

def stale_window
  @_stale_window ||= Figaro.env.stale_session_window.to_i
end

def stale_window_time
  Time.zone.now - stale_window
end

def stale?(session_data)
  return false unless session_data[:session_expires_at].present?
  return true if session_data[:session_expires_at] < Time.zone.now
  return true if session_data[:pinged_at].present? && session_data[:pinged_at] < stale_window_time
end
