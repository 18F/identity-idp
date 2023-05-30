require_relative './script_base'

class ActionAccount < ScriptBase
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

  def option_parser
    basename = File.basename($PROGRAM_NAME)

    @option_parser ||= OptionParser.new do |opts|
      opts.banner = <<~EOS
        #{basename} [subcommand] [arguments] [options]

        Example usage:

          * #{basename} review-reject uuid1 uuid2

          * #{basename} review-pass uuid1 uuid2

        Options:
      EOS

      opts.on('--help') do
        config.show_help = true
      end

      opts.on('--csv') do
        config.format = :csv
      end

      opts.on('--table', 'Output format as an ASCII table (default)') do
        config.format = :table
      end

      opts.on('--json') do
        config.format = :json
      end

      opts.on('--[no-]include-missing', <<~STR) do |include_missing|
        Whether or not to add rows in the output for missing inputs, defaults to on
      STR
        config.include_missing = include_missing
      end
    end
  end

  class ReviewReject
    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status]

      users.each do |user|
        if !user.fraud_review_pending?
          table << [user.uuid, 'Error: User does not have a pending fraud review']
          next
        end

        if FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile.reject_for_fraud(notify_user: true)

          table << [user.uuid, "User's profile has been deactivated due to fraud rejection."]
        else
          table << [user.uuid, 'User is past the 30 day review eligibility']
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, 'Error: Could not find user with that UUID']
        end
      end

      ScriptBase::Result.new(
        subtask: 'review-reject',
        uuids: users.map(&:uuid),
        table:,
      )
    end
  end

  class ReviewPass
    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status]

      users.each do |user|
        if !user.fraud_review_pending?
          table << [user.uuid, 'Error: User does not have a pending fraud review']
          next
        end

        if FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile.activate_after_passing_review

          if profile.active?
            event, _disavowal_token = UserEventCreator.new(current_user: user).
              create_out_of_band_user_event(:account_verified)

            UserAlerts::AlertUserAboutAccountVerified.call(
              user: user,
              date_time: event.created_at,
              sp_name: nil,
            )

            table << [user.uuid, "User's profile has been activated and the user has been emailed."]
          else
            table << [
              user.uuid,
              "There was an error activating the user's profile. Please try again",
            ]
          end
        else
          table << [user.uuid, 'User is past the 30 day review eligibility']
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, 'Error: Could not find user with that UUID']
        end
      end

      ScriptBase::Result.new(
        subtask: 'review-pass',
        uuids: users.map(&:uuid),
        table:,
      )
    end
  end
end
