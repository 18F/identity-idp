require 'yaml'
require 'active_support/core_ext/hash/conversions'
require 'front_matter_parser'

class I18nConverter
  def initialize(stdin:, stdout:)
    @stdin = stdin
    @stdout = stdout
  end

  def xml_to_yml
    return if bad_usage?(in_format: :xml, out_format: :yml)

    data = read_xml

    stdout.puts YAML.dump(data)
  end

  def yml_to_xml
    return if bad_usage?(in_format: :yml, out_format: :xml)

    data = YAML.safe_load(stdin.read)
    stdout.puts data.to_xml
  end

  def md_to_xml
    return if bad_usage?(in_format: :md, out_format: :xml)

    parsed = FrontMatterParser::Parser.new(:md).call(stdin.read)
    data = {
      front_matter: parsed.front_matter,
      content: parsed.content,
    }
    stdout.puts data.to_xml
  end

  def xml_to_md
    return if bad_usage?(in_format: :xml, out_format: :md)

    data = read_xml

    stdout.puts YAML.dump(data['front_matter'])
    stdout.puts '---'
    stdout.puts data['content']
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

  def read_xml
    data = Hash.from_xml(stdin.read)
    data_hash = data['hash']
    data = data_hash if data_hash
    data
  end
end
