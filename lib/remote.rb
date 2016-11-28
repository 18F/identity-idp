require 'ostruct'
require 'optparse'

# rubocop:disable Rails/Exit
class Remote
  def run(argv)
    config = parse(argv)

    execute(config)
  end

  def parse(argv)
    config = default_config

    parser = build_parser(config)
    config.command = extract_trailing_options(argv)
    parser.parse!(argv)
    parse_positional_arguments(config, argv)

    if config.show_help || !config.stage
      Kernel.puts parser
      Kernel.exit 0
    end

    config
  end

  def default_config
    OpenStruct.new(
      stage: nil,
      command: nil,
      subhost: nil,
      show_help: false
    )
  end

  def extract_trailing_options(argv)
    separator_index = argv.index('--')

    return unless separator_index

    argv.delete_at(separator_index)
    trailing = []
    trailing << argv.delete_at(separator_index) while argv[separator_index]
    trailing
  end

  def parse_positional_arguments(config, argv)
    config.stage = argv.shift if !config.stage && argv.first

    config.command = argv.first if !config.command && argv.first

    config.command ||= 'console'
  end

  def execute(config)
    remote_host = host(config)
    ssh_command = ['ssh', '-t', "ubuntu@#{remote_host}"]

    local_command = ['cd /srv/idp/current; ']
    local_command << command(config)
    local_command.flatten!

    Kernel.puts [ssh_command.join(' '), local_command.map(&:inspect)].join(' ')

    exec(*ssh_command, *local_command)
  end

  def host(config)
    [config.subhost, config.stage, 'login.gov'].compact.join('.')
  end

  def command(config)
    if config.command == 'console'
      'RAILS_ENV=production bundle exec rails console'
    elsif config.command == 'shell'
      'bash --login'
    else
      config.command
    end
  end

  def build_parser(config) # rubocop:disable Metrics/MethodLength
    OptionParser.new do |opts|
      opts.banner = <<-EOS
    Usage: #{$PROGRAM_NAME} stage (command)
           #{$PROGRAM_NAME} stage -- command to run
      EOS

      opts.on('-s', '--stage=STAGE', 'Stage/environment to connect to, default: dev') do |stage|
        config.stage = stage
      end

      command_banner = <<-EOS
    Specify the command to run, defaults to console
            console    - opens a Rails console
            shell      - opens a Bash shell in the current directory
    EOS

      opts.on('-c', '--command=COMMAND', command_banner) do |command|
        config.command = command
      end

      opts.on('-w', '--worker', 'Connect to a worker host') do
        config.subhost = 'worker'
      end

      opts.on('-h', '--help', 'Prints this help') do
        config.show_help = true
      end
    end
  end
end
