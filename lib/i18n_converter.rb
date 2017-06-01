require 'yaml'
require 'active_support/core_ext/hash/conversions'

class I18nConverter
  def initialize(stdin:, stdout:)
    @stdin = stdin
    @stdout = stdout
  end

  def xml_to_yml
    return if bad_usage?(in_format: :xml, out_format: :yml)

    data = Hash.from_xml(stdin.read)
    data_hash = data['hash']
    data = data_hash if data_hash
    stdout.puts YAML.dump(data)
  end

  def yml_to_xml
    return if bad_usage?(in_format: :yml, out_format: :xml)

    data = YAML.safe_load(stdin.read)
    stdout.puts data.to_xml
  end

  private

  attr_reader :stdin, :stdout

  def bad_usage?(in_format:, out_format:)
    return false unless stdin.tty?

    stdout.puts "Usage: cat en.#{in_format} | #{$PROGRAM_NAME} > output.#{out_format}"
    # rubocop:disable Rails/Exit
    exit 1
    # rubocop:enable Rails/Exit
    true
  end
end
