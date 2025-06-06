# frozen_string_literal: true

require_relative './script_base'

# rubocop:disable Metrics/BlockLength
class ActionAccount
  attr_reader :argv, :stdout, :stderr, :rails_env

  def initialize(argv:, stdout:, stderr:, rails_env: Rails.env)
    @argv = argv
    @stdout = stdout
    @stderr = stderr
    @rails_env = rails_env
  end

  def script_base
    @script_base ||= ScriptBase.new(
      argv:,
      stdout:,
      stderr:,
      subtask_class: subtask(argv.shift),
      banner: banner,
      reason_arg: true,
      rails_env:,
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
    def log_message(uuid:, log:, reason:, table:, messages:)
      table << [uuid, log, reason]
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
        user_already_reinstated: 'User has already been reinstated',
      }
    end
  end

  module UserActions
    include LogBase

    def perform_user_action(args:, config:, action:)
      table = []
      messages = []
      uuids = args
      table << %w[uuid status reason]

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
          elsif user.reinstated?
            log_texts << (log_text[:user_already_reinstated] + " (at #{user.reinstated_at})")
          else
            log_texts << log_text[:user_is_not_suspended]
          end
        when :confirm_suspend
          if user.suspended?
            user.send_email_to_all_addresses(:suspension_confirmed)
            analytics(user).user_suspension_confirmed
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
            reason: config.reason,
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
            reason: config.reason,
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

    def analytics(user)
      Analytics.new(
        user: user, request: nil, session: {}, sp: nil,
      )
    end
  end

  class ReviewReject
    include LogBase
    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status reason]

      messages = []

      users.each do |user|
        profile = nil
        profile_fraud_review_pending_at = nil
        success = false

        log_texts = []

        if !user.fraud_review_pending?
          log_texts << log_text[:no_pending]
        elsif FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile_fraud_review_pending_at = profile.fraud_review_pending_at
          profile.in_person_enrollment&.failed!
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
            reason: config.reason,
            table:,
            messages:,
          )
        end
      ensure
        if !success
          analytics_error_hash = { message: log_texts.last }
        end

        Analytics.new(
          user: user,
          request: nil,
          session: {},
          sp: profile&.initiating_service_provider_issuer,
        ).fraud_review_rejected(
          success:,
          errors: analytics_error_hash,
          exception: nil,
          profile_fraud_review_pending_at:,
          profile_age_in_seconds: profile&.profile_age_in_seconds,
        )
      end

      missing_uuids = (uuids - users.map(&:uuid))

      if config.include_missing? && !missing_uuids.empty?
        missing_uuids.each do |missing_uuid|
          table, messages = log_message(
            uuid: missing_uuid,
            log: log_text[:missing_uuid],
            reason: config.reason,
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
          profile_age_in_seconds: nil,
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

    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status reason]

      messages = []
      users.each do |user|
        profile = nil
        profile_fraud_review_pending_at = nil
        success = false
        reproof = user.has_proofed_before?

        log_texts = []
        if !user.fraud_review_pending?
          log_texts << log_text[:no_pending]
        elsif FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile_fraud_review_pending_at = profile.fraud_review_pending_at
          profile.in_person_enrollment&.passed!
          profile.activate_after_passing_review
          success = true

          if profile.active?
            attempts_api_tracker(profile:).idv_enrollment_complete(reproof:)
            UserEventCreator.new(current_user: user)
              .create_out_of_band_user_event(:account_verified)
            UserAlerts::AlertUserAboutAccountVerified.call(profile: profile)

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
            reason: config.reason,
            table:,
            messages:,
          )
        end
      ensure
        if !success
          analytics_error_hash = { message: log_texts.last }
        end

        Analytics.new(
          user: user,
          request: nil,
          session: {},
          sp: profile&.initiating_service_provider_issuer,
        ).fraud_review_passed(
          success:,
          errors: analytics_error_hash,
          exception: nil,
          profile_fraud_review_pending_at: profile_fraud_review_pending_at,
          profile_age_in_seconds: profile&.profile_age_in_seconds,
        )
      end

      missing_uuids = (uuids - users.map(&:uuid))
      if config.include_missing? && !missing_uuids.empty?
        missing_uuids.each do |missing_uuid|
          table, messages = log_message(
            uuid: missing_uuid,
            log: log_text[:missing_uuid],
            reason: config.reason,
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
          profile_age_in_seconds: nil,
        )
      end

      ScriptBase::Result.new(
        subtask: 'review-pass',
        uuids: users.map(&:uuid),
        messages:,
        table:,
      )
    end

    def attempts_api_tracker(profile:)
      AttemptsApi::Tracker.new(
        enabled_for_session: profile.initiating_service_provider&.attempts_api_enabled?,
        session_id: nil,
        request: nil,
        user: profile.user,
        sp: profile.initiating_service_provider,
        cookie_device_uuid: nil,
        sp_request_uri: nil,
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
