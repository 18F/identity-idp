# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `GpoReminderJob`.
# Please instead update this file by running `bin/tapioca dsl GpoReminderJob`.


class GpoReminderJob
  class << self
    sig do
      params(
        cutoff_time_for_sending_reminders: T.untyped,
        block: T.nilable(T.proc.params(job: GpoReminderJob).void)
      ).returns(T.any(GpoReminderJob, FalseClass))
    end
    def perform_later(cutoff_time_for_sending_reminders, &block); end

    sig { params(cutoff_time_for_sending_reminders: T.untyped).returns(T.untyped) }
    def perform_now(cutoff_time_for_sending_reminders); end
  end
end