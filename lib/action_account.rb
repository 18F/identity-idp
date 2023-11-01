require_relative './script_base'

# rubocop:disable Metrics/BlockLength
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

          * #{basename} suspend-user uuid1 uuid2

          * #{basename} reinstate-user uuid1 uuid2

          * #{basename} confirm-suspend-user uuid1 uuid2
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
      'suspend-user' => SuspendUser,
      'reinstate-user' => ReinstateUser,
      'confirm-suspend-user' => ConfirmSuspendUser,
    }[name]
  end

  module LogBase
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
        user_emailed: 'User has been emailed',
        user_suspended: 'User has been suspended',
        user_reinstated: 'User has been reinstated and the user has been emailed',
        user_already_suspended: 'User has already been suspended',
        user_is_not_suspended: 'User is not suspended',
      }
    end
  end

  module UserActions
    include LogBase

    def perform_user_action(args:, config:, action:)
      table = []
      messages = []
      uuids = args
      table << %w[uuid status]

      users = User.where(uuid: uuids).order(:uuid)
      users.each do |user|
        log_texts = []
        case action
        when :suspend
          if user.suspended?
            log_texts << log_text[:user_already_suspended]
          else
            user.suspend!
            log_texts << log_text[:user_suspended]
          end
        when :reinstate
          if user.suspended?
            user.reinstate!
            log_texts << log_text[:user_reinstated]
          else
            log_texts << log_text[:user_is_not_suspended]
          end
        when :confirm_suspend
          if user.suspended?
            user.send_email_to_all_addresses(:suspension_confirmed)
            log_texts << log_text[:user_emailed]
          else
            log_texts << log_text[:user_is_not_suspended]
          end
        else
          raise "unknown subtask=#{action}"
        end

        log_texts.each do |text|
          table, messages = log_message(
            uuid: user.uuid,
            log: text,
            table:,
            messages:,
          )
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table, messages = log_message(
            uuid: missing_uuid,
            log: log_text[:missing_uuid],
            table:,
            messages:,
          )
        end
      end

      ScriptBase::Result.new(
        subtask: "#{action.to_s.dasherize}-user",
        uuids: users.map(&:uuid),
        messages:,
        table:,
      )
    end
  end

  class ReviewReject
    include LogBase
    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status]

      messages = []

      users.each do |user|
        profile_fraud_review_pending_at = nil
        success = false

        log_texts = []

        if !user.fraud_review_pending?
          log_texts << log_text[:no_pending]
        elsif FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile_fraud_review_pending_at = profile.fraud_review_pending_at
          profile.reject_for_fraud(notify_user: true)
          success = true

          log_texts << log_text[:rejected_for_fraud]
        else
          log_texts << log_text[:past_eligibility]
        end

        log_texts.each do |text|
          table, messages = log_message(
            uuid: user.uuid,
            log: text,
            table:,
            messages:,
          )
        end
      ensure
        if !success
          analytics_error_hash = { message: log_texts.last }
        end

        Analytics.new(
          user: user, request: nil, session: {}, sp: nil,
        ).fraud_review_rejected(
          success:,
          errors: analytics_error_hash,
          exception: nil,
          profile_fraud_review_pending_at: profile_fraud_review_pending_at,
        )
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table, messages = log_message(
            uuid: missing_uuid,
            log: log_text[:missing_uuid],
            table:,
            messages:,
          )
        end
        Analytics.new(
          user: AnonymousUser.new, request: nil, session: {}, sp: nil,
        ).fraud_review_rejected(
          success: false,
          errors: { message: log_text[:missing_uuid] },
          exception: nil,
          profile_fraud_review_pending_at: nil,
        )
      end

      ScriptBase::Result.new(
        subtask: 'review-reject',
        uuids: users.map(&:uuid),
        messages:,
        table:,
      )
    end
  end

  class ReviewPass
    include LogBase

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
        profile_fraud_review_pending_at = nil
        success = false

        log_texts = []
        if !user.fraud_review_pending?
          log_texts << log_text[:no_pending]
        elsif FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile_fraud_review_pending_at = profile.fraud_review_pending_at
          profile.activate_after_passing_review
          success = true

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
            uuid: user.uuid,
            log: text,
            table:,
            messages:,
          )
        end
      ensure
        if !success
          analytics_error_hash = { message: log_texts.last }
        end

        Analytics.new(
          user: user, request: nil, session: {}, sp: nil,
        ).fraud_review_passed(
          success:,
          errors: analytics_error_hash,
          exception: nil,
          profile_fraud_review_pending_at: profile_fraud_review_pending_at,
        )
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table, messages = log_message(
            uuid: missing_uuid,
            log: log_text[:missing_uuid],
            table:,
            messages:,
          )
        end
        Analytics.new(
          user: AnonymousUser.new, request: nil, session: {}, sp: nil,
        ).fraud_review_passed(
          success: false,
          errors: { message: log_text[:missing_uuid] },
          exception: nil,
          profile_fraud_review_pending_at: nil,
        )
      end

      ScriptBase::Result.new(
        subtask: 'review-pass',
        uuids: users.map(&:uuid),
        messages:,
        table:,
      )
    end
  end

  class SuspendUser
    include UserActions

    def run(args:, config:)
      perform_user_action(
        args:,
        config:,
        action: :suspend,
      )
    end
  end

  class ReinstateUser
    include UserActions

    def run(args:, config:)
      perform_user_action(
        args:,
        config:,
        action: :reinstate,
      )
    end
  end

  class ConfirmSuspendUser
    include UserActions

    def run(args:, config:)
      perform_user_action(
        args:,
        config:,
        action: :confirm_suspend,
      )
    end
  end
end
# rubocop:enable Metrics/BlockLength
