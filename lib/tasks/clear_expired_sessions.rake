# Rake task for clearing out expired or stale sessions.
#
#  - http://blog.brightbox.co.uk/posts/clearing-out-rails-sessions

desc 'Clear expired sessions'
task clear_expired_sessions: :environment do
  ActiveRecord::SessionStore::Session.delete_all(
    ['updated_at < ?', 1.day.ago])
end
