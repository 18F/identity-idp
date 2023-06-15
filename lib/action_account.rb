require_relative './script_base'

class ActionAccount
  attr_reader :argv, :stdout, :stderr

  def initialize(argv:, stdout:, stderr:)
    @argv = argv
    @stdout = stdout
    @stderr = stderr
  end

  def script_base
    @script_base ||= ScriptBase.new(
      argv:,
      stdout:,
      stderr:,
      subtask_class: subtask(argv.shift),
      banner: banner,
    )
  end

  def run
    script_base.run
  end

  def banner
    basename = File.basename($PROGRAM_NAME)
    <<~EOS
      #{basename} [subcommand] [arguments] [options]
        Example usage:

          * #{basename} review-reject uuid1 uuid2

          * #{basename} review-pass uuid1 uuid2

        Options:
    EOS
  end

  # @api private
  # A subtask is a class that has a run method, the type signature should look like:
  # +#run(args: Array<String>, config: Config) -> Result+
  # @return [Class,nil]
  def subtask(name)
    {
      'review-reject' => ReviewReject,
      'review-pass' => ReviewPass,
    }[name]
  end

  class ReviewAction
    def log_message(uuid:, log:, table:, messages:)
      table << [uuid, log]
      messages << '`' + uuid + '`: ' + log
      [table, messages]
    end

    def log_text
      {
        no_pending: 'Error: User does not have a pending fraud review',
        rejected_for_fraud: "User's profile has been deactivated due to fraud rejection.",
        profile_activated: "User's profile has been activated and the user has been emailed.",
        error_activating: "There was an error activating the user's profile. Please try again.",
        past_eligibility: 'User is past the 30 day review eligibility.',
        missing_uuid: 'Error: Could not find user with that UUID',
      }
    end
  end

  class ReviewReject < ReviewAction
    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status]

      messages = []

      users.each do |user|
        log_texts = []

        if !user.fraud_review_pending?
          log_texts << log_text[:no_pending]
        elsif FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile.reject_for_fraud(notify_user: true)

          log_texts << log_text[:rejected_for_fraud]
        else
          log_texts << log_text[:past_eligibility]
        end

        log_texts.each do |text|
          table, messages = log_message(
            uuid: user.uuid, log: text, table: table,
            messages: messages
          )
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table, messages = log_message(
            uuid: missing_uuid, log: log_text[:missing_uuid],
            table: table, messages: messages
          )
        end
      end

      ScriptBase::Result.new(
        subtask: 'review-reject',
        uuids: users.map(&:uuid),
        messages:,
        table:,
      )
    end
  end

  class ReviewPass < ReviewAction
    def alert_verified(user:, date_time:)
      UserAlerts::AlertUserAboutAccountVerified.call(
        user: user,
        date_time: date_time,
        sp_name: nil,
      )
    end

    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status]

      messages = []
      users.each do |user|
        log_texts = []
        if !user.fraud_review_pending?
          log_texts << log_text[:no_pending]
        elsif FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile.activate_after_passing_review

          if profile.active?
            event, _disavowal_token = UserEventCreator.new(current_user: user).
              create_out_of_band_user_event(:account_verified)

            alert_verified(user: user, date_time: event.created_at)

            log_texts << log_text[:profile_activated]
          else
            log_texts << log_text[:error_activating]
          end
        else
          log_texts << log_text[:past_eligibility]
        end

        log_texts.each do |text|
          table, messages = log_message(
            uuid: user.uuid, log: text, table: table,
            messages: messages
          )
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table, messages = log_message(
            uuid: missing_uuid, log: log_text[:missing_uuid],
            table: table, messages: messages
          )
        end
      end

      ScriptBase::Result.new(
        subtask: 'review-pass',
        uuids: users.map(&:uuid),
        messages:,
        table:,
      )
    end
  end
end
