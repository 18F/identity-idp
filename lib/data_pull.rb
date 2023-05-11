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
    :subtask, # name of subtask, used for audit logging
    :uuids, # Array of UUIDs entered or returned, used for audit logging
    keyword_init: true,
  )

  Config = Struct.new(
    :include_missing,
    :format,
    :show_help,
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

    result = subtask_class.new.run(args: argv, include_missing: config.include_missing?)

    stderr.puts "*Task*: `#{result.subtask}`"
    stderr.puts "*UUIDs*: #{result.uuids.map { |uuid| "`#{uuid}`" }.join(', ')}"

    render_output(result.table)
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
  # +#run(args: Array<String>, include_missing: Boolean) -> Result+
  # @return [Class,nil]
  def subtask(name)
    {
      'uuid-lookup' => UuidLookup,
      'uuid-convert' => UuidConvert,
      'email-lookup' => EmailLookup,
    }[name]
  end

  def option_parser
    @option_parser ||= OptionParser.new do |opts|
      opts.banner = <<~EOS
        #{$PROGRAM_NAME} [subcommand] [arguments] [options]

        Example usage:

          * #{$PROGRAM_NAME} uuid-lookup email1@example.com email2@example.com

          * #{$PROGRAM_NAME} uuid-convert partner-uuid1 partner-uuid2

          * #{$PROGRAM_NAME} email-lookup uuid1 uuid2

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
        Whether or not to add rows in the output for missing inputs, defaults to off
      STR
        config.include_missing = include_missing
      end
    end
  end

  class UuidLookup
    def run(args:, include_missing:)
      emails = args

      table = []
      table << %w[email uuid]

      uuids = []

      emails.each do |email|
        user = User.find_with_email(email)
        if user
          table << [email, user.uuid]
          uuids << user.uuid
        elsif include_missing
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
    def run(args:, include_missing:)
      partner_uuids = args

      table = []
      table << %w[partner_uuid source internal_uuid]
      identities = AgencyIdentity.includes(:user, :agency).where(uuid: partner_uuids).order(:uuid)

      identities.each do |identity|
        table << [identity.uuid, identity.agency.name, identity.user.uuid]
      end

      if include_missing
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
    def run(args:, include_missing:)
      uuids = args

      users = User.includes(:email_addresses).where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid email confirmed_at]

      users.each do |user|
        user.email_addresses.sort_by(&:id).each do |email_address|
          table << [user.uuid, email_address.email, email_address.confirmed_at]
        end
      end

      if include_missing
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
end
