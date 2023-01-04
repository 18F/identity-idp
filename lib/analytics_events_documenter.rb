#!/usr/bin/env ruby
require 'yard'
require 'json'
require 'optparse'
require 'stringio'
require 'active_support/core_ext/object/blank'
require_relative './identity_config'

# Parses YARD output for AnalyticsEvents methods
class AnalyticsEventsDocumenter
  DEFAULT_DATABASE_PATH = '.yardoc'
  PREVIOUS_EVENT_NAME_TAG = :'identity.idp.previous_event_name'

  DOCUMENTATION_OPTIONAL_PARAMS = %w[
    pii_like_keypaths
  ]

  attr_reader :database_path, :class_name

  # @return [(String, Integer)] returns a tuple of (output, exit_status)
  def self.run(argv)
    exit_status = 0
    output = StringIO.new
    check = false
    json = false
    help = false
    require_extra_params = true
    class_name = 'AnalyticsEvents'

    parser = OptionParser.new do |opts|
      opts.on('--check', 'Checks that all params are documented, will exit 1 if missing') do
        check = true
      end

      opts.on('--json') do
        json = true
      end

      opts.on('--skip-extra-params') do
        require_extra_params = false
      end

      opts.on('--class-name=CLASS_NAME') do |c|
        class_name = c
      end

      opts.on('--help', 'print this help message') do
        help = true
      end
    end

    parser.parse!(argv)

    documenter = new(
      database_path: argv.first,
      class_name: class_name,
      require_extra_params: require_extra_params,
    )

    if help || (!check && !json)
      output.puts parser
    elsif check
      missing_documentation = documenter.missing_documentation
      if missing_documentation.present?
        output.puts missing_documentation
        exit_status = 1
      else
        output.puts "All #{class_name} methods are documented! 🚀"
      end
    elsif json
      output.puts JSON.pretty_generate(documenter.as_json)
    end

    [output.string.presence, exit_status]
  end

  def initialize(database_path:, class_name:, require_extra_params:)
    @database_path = database_path || DEFAULT_DATABASE_PATH
    @class_name = class_name
    @require_extra_params = require_extra_params
  end

  def require_extra_params?
    !!@require_extra_params
  end

  # Checks for params that are missing documentation, and returns a list of
  # @return [Array<String>]
  def missing_documentation
    analytics_methods.flat_map do |method_object|
      error_prefix = "#{method_object.file}:#{method_object.line} #{method_object.name}"
      errors = []

      param_names = method_object.parameters.map { |p| p.first }
      _splat_params, other_params = param_names.partition { |p| p.start_with?('**') }
      keyword_params, other_params = other_params.partition { |p| p.end_with?(':') }
      if other_params.present?
        errors << "#{error_prefix} unexpected positional parameters #{other_params.inspect}"
      end

      keyword_param_names = keyword_params.map { |p| p.chomp(':') }
      documented_params = method_object.tags('param').map(&:name)
      missing_attributes = keyword_param_names - documented_params - DOCUMENTATION_OPTIONAL_PARAMS

      if !extract_event_name(method_object)
        errors << "#{error_prefix} event name not detected in track_event"
      end

      missing_attributes.each do |attribute|
        errors << "#{error_prefix} #{attribute} (undocumented)"
      end

      if require_extra_params? && param_names.size > 0 && !param_names.last.start_with?('**')
        errors << "#{error_prefix} missing **extra"
      end

      if method_object.signature.end_with?('*)')
        errors << "#{error_prefix} don't use * as an argument, remove all args or name args"
      end

      method_object.tags('param').each do |tag|
        errors << "#{error_prefix} #{tag.name} missing types" if !tag.types
      end

      errors
    end
  end

  # @return [{ events: Array<Hash>}]
  def as_json
    events_json_summary = analytics_methods.map do |method_object|
      attributes = method_object.tags('param').map do |tag|
        {
          name: tag.name,
          types: tag.types,
          description: tag.text.presence,
        }
      end.compact

      {
        event_name: extract_event_name(method_object),
        previous_event_names: method_object.tags(PREVIOUS_EVENT_NAME_TAG).map(&:text),
        description: method_object.docstring.presence,
        attributes: attributes,
        method_name: method_object.name,
        source_line: method_object.line,
        source_file: method_object.file,
        source_sha: IdentityConfig::GIT_SHA,
      }
    end

    { events: events_json_summary }
  end

  private

  # Naive attempt to pull tracked event string from source code
  def extract_event_name(method_object)
    m = /track_event\(\s*[:"'](?<event_name>[^"']+)["',)]/.match(method_object.source)
    m && m[:event_name]
  end

  def database
    @database ||= YARD::Serializers::YardocSerializer.new(database_path).deserialize('root')
  end

  # @return [Array<YARD::CodeObjects::MethodObject>]
  def analytics_methods
    class_name_parts = class_name.split('::').map(&:to_sym)

    database.select do |_k, object|
      # this check will fail if the namespace is nested more than once
      method_object_name_parts = [object.namespace&.parent&.name, object.namespace&.name].
        select { |part| part.present? && part != :root }

      object.type == :method && method_object_name_parts == class_name_parts
    end.values
  end
end

# rubocop:disable Rails/Output
# rubocop:disable Rails/Exit
if $PROGRAM_NAME == __FILE__
  output, status = AnalyticsEventsDocumenter.run(ARGV)
  puts output
  exit status
end
# rubocop:enable Rails/Exit
# rubocop:enable Rails/Output
