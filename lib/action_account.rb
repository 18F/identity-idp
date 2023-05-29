require 'optparse'

class ActionAccount
  attr_reader :argv, :stdout, :stderr

  def initialize(argv:, stdout:, stderr:)
    @argv   = argv
    @stdout = stdout
    @stderr = stderr
  end

  Result = Struct.new(
    :table,   # tabular output, rendered as an ASCII table or as CSV
    :json,    # output that should only be formatted as JSON
    :subtask, # name of subtask, used for audit logging
    :uuids,   # Array of UUIDs entered or returned, used for audit logging
  )

  Config = Struct.new(
    :include_missing,
    :format,
    :show_help,
  ) do
    alias_method :include_missing?, :include_missing
    alias_method :show_help?, :show_help
  end

  def config
    @config ||= Config.new(
      include_missing: true,
      format: :table,
      show_help: false,
    )
  end

  def run
    option_parser.parse!(argv)
    subtask_class = subtask(argv.shift)

    if config.show_help? || !subtask_class
      stderr.puts '*Task*: `help`'
      stderr.puts '*UUIDs*: N/A'

      stdout.puts option_parser
      return
    end

    result = subtask_class.new.run(args: argv, config:)

    stderr.puts "*Task*: `#{result.subtask}`"
    stderr.puts "*UUIDs*: #{result.uuids.map { |uuid| "`#{uuid}`" }.join(', ')}"

    if result.json
      stdout.puts result.json.to_json
    else
      render_output(result.table)
    end
  end

  # @param [Array<Array<String>>] rows
  def render_output(rows)
    return if rows.blank?

    case config.format
    when :table
      require 'terminal-table'
      table = Terminal::Table.new
      header, *body = rows
      table << header
      table << :separator
      body.each do |row|
        table << row
      end
      stdout.puts table
    when :csv
      require 'csv'
      CSV.instance(stdout) do |csv|
        rows.each do |row|
          csv << row
        end
      end
    when :json
      headers, *body = rows

      objects = body.map do |values|
        headers.zip(values).to_h
      end

      stdout.puts JSON.pretty_generate(objects)
    else
      raise "Unknown format=#{config.format}"
    end
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

      Result.new(
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

      Result.new(
        subtask: 'review-pass',
        uuids: users.map(&:uuid),
        table:,
      )
    end
  end
end
