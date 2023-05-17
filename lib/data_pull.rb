require 'optparse'

class DataPull
  attr_reader :argv, :stdout, :stderr

  def initialize(argv:, stdout:, stderr:)
    @argv = argv
    @stdout = stdout
    @stderr = stderr
  end

  Result = Struct.new(
    :table, # tabular output, rendered as an ASCII table or as CSV
    :json, # output that should only be formatted as JSON
    :subtask, # name of subtask, used for audit logging
    :uuids, # Array of UUIDs entered or returned, used for audit logging
    keyword_init: true,
  )

  Config = Struct.new(
    :include_missing,
    :format,
    :show_help,
    :requesting_issuers,
    keyword_init: true,
  ) do
    alias_method :include_missing?, :include_missing
    alias_method :show_help?, :show_help
  end

  def config
    @config ||= Config.new(
      include_missing: true,
      format: :table,
      show_help: false,
      requesting_issuers: [],
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
      'uuid-lookup' => UuidLookup,
      'uuid-convert' => UuidConvert,
      'email-lookup' => EmailLookup,
      'ig-request' => InspectorGeneralRequest,
    }[name]
  end

  # rubocop:disable Metrics/BlockLength
  def option_parser
    basename = File.basename($PROGRAM_NAME)

    @option_parser ||= OptionParser.new do |opts|
      opts.banner = <<~EOS
        #{basename} [subcommand] [arguments] [options]

        Example usage:

          * #{basename} uuid-lookup email1@example.com email2@example.com

          * #{basename} uuid-convert partner-uuid1 partner-uuid2

          * #{basename} email-lookup uuid1 uuid2

          * #{basename} ig-request uuid1 uuid2 --requesting-issuer ABC:DEF:GHI

        Options:
      EOS

      opts.on('-r=ISSUER', '--requesting-issuer=ISSUER', <<-MSG) do |issuer|
        requesting issuer (used for ig-request task)
      MSG
        config.requesting_issuers << issuer
      end

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
  # rubocop:enable Metrics/BlockLength

  class UuidLookup
    def run(args:, config:)
      emails = args

      table = []
      table << %w[email uuid]

      uuids = []

      emails.each do |email|
        user = User.find_with_email(email)
        if user
          table << [email, user.uuid]
          uuids << user.uuid
        elsif config.include_missing?
          table << [email, '[NOT FOUND]']
        end
      end

      Result.new(
        subtask: 'uuid-lookup',
        table:,
        uuids:,
      )
    end
  end

  class UuidConvert
    def run(args:, config:)
      partner_uuids = args

      table = []
      table << %w[partner_uuid source internal_uuid]
      identities = AgencyIdentity.includes(:user, :agency).where(uuid: partner_uuids).order(:uuid)

      identities.each do |identity|
        table << [identity.uuid, identity.agency.name, identity.user.uuid]
      end

      if config.include_missing?
        (partner_uuids - identities.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, '[NOT FOUND]', '[NOT FOUND]']
        end
      end

      Result.new(
        subtask: 'uuid-convert',
        uuids: identities.map { |u| u.user.uuid },
        table:,
      )
    end
  end

  class EmailLookup
    def run(args:, config:)
      uuids = args

      users = User.includes(:email_addresses).where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid email confirmed_at]

      users.each do |user|
        user.email_addresses.sort_by(&:id).each do |email_address|
          table << [user.uuid, email_address.email, email_address.confirmed_at]
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, '[NOT FOUND]', nil]
        end
      end

      Result.new(
        subtask: 'email-lookup',
        uuids: users.map(&:uuid),
        table:,
      )
    end
  end

  class InspectorGeneralRequest
    def run(args:, config:)
      require 'data_requests/deployed'
      ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
      uuids = args

      users = uuids.map { |uuid| DataRequests::Deployed::LookupUserByUuid.new(uuid).call }.compact
      shared_device_users = DataRequests::Deployed::LookupSharedDeviceUsers.new(users).call

      output = shared_device_users.map do |user|
        DataRequests::Deployed::CreateUserReport.new(user, config.requesting_issuers).call
      end

      Result.new(
        subtask: 'ig-request',
        uuids: users.map(&:uuid),
        json: output,
      )
    end
  end
end
