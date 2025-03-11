# frozen_string_literal: true

require 'optparse'

class ScriptBase
  attr_reader :argv, :stdout, :stderr, :subtask_class, :banner, :rails_env

  def initialize(
    argv:,
    stdout:,
    stderr:,
    subtask_class:,
    banner:,
    reason_arg:,
    rails_env: Rails.env
  )
    @argv = argv
    @stdout = stdout
    @stderr = stderr
    @subtask_class = subtask_class
    @banner = banner
    @reason_arg = reason_arg
    @rails_env = rails_env
  end

  def reason_arg?
    !!@reason_arg
  end

  Result = Struct.new(
    :table,    # tabular output, rendered as an ASCII table or as CSV
    :json,     # output that should only be formatted as JSON
    :subtask,  # name of subtask, used for audit logging
    :uuids,    # Array of UUIDs entered or returned, used for audit logging
    :messages, # Array of UUIDs and messages returned, used for logging
    keyword_init: true,
  )

  Config = Struct.new(
    :include_missing,
    :format,
    :show_help,
    :requesting_issuers,
    :deflate,
    :depth,
    :reason,
    keyword_init: true,
  ) do
    alias_method :include_missing?, :include_missing
    alias_method :show_help?, :show_help
    alias_method :deflate?, :deflate
  end

  def config
    @config ||= Config.new(
      include_missing: true,
      format: :table,
      show_help: false,
      requesting_issuers: [],
      deflate: false,
      reason: nil,
    )
  end

  def run
    option_parser.parse!(argv)

    if rails_env.local?
      stderr.puts "⚠️ WARNING: returning local data for #{File.basename($PROGRAM_NAME)}"
    end

    if config.show_help? || !subtask_class
      stderr.puts '*Task*: `help`'
      stderr.puts '*UUIDs*: N/A'

      stdout.puts option_parser
      return
    end

    result = subtask_class.new.run(args: argv, config:)

    stderr.puts "*Task*: `#{result.subtask}`"
    stderr.puts "*UUIDs*: #{result.uuids.map { |uuid| "`#{uuid}`" }.join(', ')}"
    if result.messages.present?
      stderr.puts "*Messages*:\n#{result.messages.map { |message| "    • #{message}" }.join("\n")}"
    end

    if config.deflate?
      require 'zlib'
      require 'base64'
      stdout.puts Base64.encode64(
        Zlib::Deflate.deflate(
          (result.json || result.table).to_json,
          Zlib::BEST_COMPRESSION,
        ),
      )
    elsif result.json
      stdout.puts result.json.to_json
    else
      self.class.render_output(result.table, format: config.format, stdout: stdout)
    end
  rescue => err
    self.class.render_output(
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
      ],
      format: config.format,
      stdout: stdout,
    )
  end

  # rubocop:disable Metrics/BlockLength
  def option_parser
    @option_parser ||= OptionParser.new do |opts|
      opts.banner = banner

      opts.on('-i=ISSUER', '--requesting-issuer=ISSUER', <<-MSG) do |issuer|
        requesting issuer (used for ig-request task)
      MSG
        config.requesting_issuers << issuer
      end

      opts.on('--depth=DEPTH', <<-MSG) do |depth|
        depth of connected devices (used for ig-request task)
      MSG
        config.depth = depth.to_i
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

      opts.on('--deflate', 'Use DEFLATE compression on the output') do
        config.deflate = true
      end

      opts.on('--[no-]include-missing', <<~STR) do |include_missing|
        Whether or not to add rows in the output for missing inputs, defaults to on
      STR
        config.include_missing = include_missing
      end

      if reason_arg?
        opts.on('--reason=REASON', 'Reason for command') do |reason|
          config.reason = reason
        end
      end
    end
  end
  # rubocop:enable Metrics/BlockLength

  # @param [Array<Array<String>>] rows
  def self.render_output(rows, format:, stdout: STDOUT)
    return if rows.blank?

    case format
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
      raise "Unknown format=#{format}"
    end
  end
end
