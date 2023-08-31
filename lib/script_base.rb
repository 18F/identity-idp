require 'optparse'

class ScriptBase
  attr_reader :argv, :stdout, :stderr, :subtask_class, :banner

  def initialize(argv:, stdout:, stderr:, subtask_class:, banner:)
    @argv = argv
    @stdout = stdout
    @stderr = stderr
    @subtask_class = subtask_class
    @banner = banner
  end

  Result = Struct.new(
    :table,   # tabular output, rendered as an ASCII table or as CSV
    :json,    # output that should only be formatted as JSON
    :subtask, # name of subtask, used for audit logging
    :uuids,   # Array of UUIDs entered or returned, used for audit logging
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

  def option_parser
    @option_parser ||= OptionParser.new do |opts|
      opts.banner = banner

      opts.on('-i=ISSUER', '--requesting-issuer=ISSUER', <<-MSG) do |issuer|
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
end
