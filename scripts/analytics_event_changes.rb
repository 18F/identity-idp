#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'optparse'

module AnalyticsEventChanges
  ANALYTICS_EVENTS_FILE = 'app/services/analytics_events.rb'
  EVENT_DEFINITION_PATTERN = /^\s*def\s+(?<method_name>[a-z]\w*)\b/
  ANALYTICS_METHOD_INVOCATION_PATTERN =
    /\banalytics\.(?<method_name>(?!track_event\b)[a-z]\w*[!?=]?)\b/
  ANALYTICS_TRACK_EVENT_INVOCATION_PATTERN =
    /\banalytics\.track_event\(\s*(?::(?<symbol_event>[a-z]\w*)|['"](?<string_event>[^'"]+)['"])/
  SPLATTED_KEYWORD_ARGUMENT_PATTERN = /\*\*(?<name>[a-z]\w*)\b/

  Change = Struct.new(:type, :file, :line, :method_name, :source, keyword_init: true)
  EventDefinition = Struct.new(:method_name, :source, :line, keyword_init: true)
  EventInvocation = Struct.new(:method_name, :source, :line, keyword_init: true)

  module_function

  def parsed_options(args)
    options = { base_branch: 'main', source_branch: 'HEAD' }
    basename = File.basename($PROGRAM_NAME)

    OptionParser.new do |opts|
      opts.banner = <<~HELP
        usage: #{basename} [OPTIONS]

        Detects analytics event definition and invocation changes between two git refs.
      HELP

      opts.on('-b', '--base_branch BASE_BRANCH', 'Name of base branch, defaults to main') do |val|
        options[:base_branch] = val
      end

      opts.on(
        '-s',
        '--source_branch SOURCE_BRANCH',
        'Name of source branch, defaults to HEAD',
      ) do |val|
        options[:source_branch] = val
      end
    end.parse!(args)

    options
  end

  def git_output(*args, allow_failure: false)
    output, error, status = Open3.capture3('git', *args)
    return nil if allow_failure && !status.success?

    raise "git #{args.join(' ')} failed: #{error}" unless status.success?

    output
  end

  def merge_base(base_branch, source_branch)
    ref = git_output('merge-base', base_branch, source_branch, allow_failure: true)&.strip
    ref.nil? || ref.empty? ? base_branch : ref
  end

  def changed_files(base_branch:, source_branch:)
    base_ref = merge_base(base_branch, source_branch)
    git_output(
      'diff',
      '--name-only',
      '--diff-filter=ACMRT',
      "#{base_ref}..#{source_branch}",
    ).lines.map(&:strip).reject(&:empty?)
  end

  def file_content(ref, path)
    git_output('show', "#{ref}:#{path}", allow_failure: true) || ''
  end

  def detect_from_git(base_branch:, source_branch:)
    base_ref = merge_base(base_branch, source_branch)
    files = changed_files(base_branch: base_ref, source_branch: source_branch)
    # rubocop:disable Rails/IndexWith
    source_files = files.each_with_object({}) do |file, hash|
      hash[file] = file_content(source_branch, file)
    end
    base_files = (files | [ANALYTICS_EVENTS_FILE]).each_with_object({}) do |file, hash|
      hash[file] = file_content(base_ref, file)
    end
    # rubocop:enable Rails/IndexWith

    detect(
      changed_files: files,
      base_files: base_files,
      source_files: source_files,
    )
  end

  def detect(changed_files:, base_files:, source_files:)
    base_definitions = extract_event_definitions(base_files.fetch(ANALYTICS_EVENTS_FILE, ''))
    source_definitions = extract_event_definitions(source_files.fetch(ANALYTICS_EVENTS_FILE, ''))
    known_event_methods = (base_definitions.keys | source_definitions.keys)

    definition_changes(base_definitions, source_definitions) +
      invocation_changes(changed_files, base_files, source_files, known_event_methods)
  end

  def definition_changes(base_definitions, source_definitions)
    new_events = source_definitions.keys - base_definitions.keys
    changed_events = source_definitions.keys & base_definitions.keys

    new_events.map do |method_name|
      definition = source_definitions.fetch(method_name)
      Change.new(
        type: :new_event,
        file: ANALYTICS_EVENTS_FILE,
        line: definition.line,
        method_name: method_name,
        source: first_line(definition.source),
      )
    end + changed_events.filter_map do |method_name|
      base_definition = base_definitions.fetch(method_name)
      source_definition = source_definitions.fetch(method_name)
      next if normalize_source(base_definition.source) == normalize_source(source_definition.source)

      Change.new(
        type: :changed_event_definition,
        file: ANALYTICS_EVENTS_FILE,
        line: source_definition.line,
        method_name: method_name,
        source: first_line(source_definition.source),
      )
    end
  end

  def invocation_changes(changed_files, base_files, source_files, known_event_methods)
    changed_files
      .grep(/\.rb\z/)
      .reject { |file| file == ANALYTICS_EVENTS_FILE }
      .flat_map do |file|
        base_invocations = invocation_counts(
          extract_event_invocations(base_files.fetch(file, ''), known_event_methods),
        )
        source_invocations = extract_event_invocations(
          source_files.fetch(file, ''),
          known_event_methods,
        )

        source_invocations.filter_map do |invocation|
          key = invocation_key(invocation)
          next if base_invocations[key].to_i.positive? && (base_invocations[key] -= 1)

          Change.new(
            type: :new_or_changed_invocation,
            file: file,
            line: invocation.line,
            method_name: invocation.method_name,
            source: first_line(invocation.source),
          )
        end
      end
  end

  def invocation_counts(invocations)
    invocations.each_with_object(Hash.new(0)) do |invocation, counts|
      counts[invocation_key(invocation)] += 1
    end
  end

  def invocation_key(invocation)
    [invocation.method_name, normalize_source(invocation.source)]
  end

  def extract_event_definitions(source)
    lines = source.lines
    lines.each_with_index.filter_map do |line, index|
      match = EVENT_DEFINITION_PATTERN.match(line)
      next unless match

      method_name = match[:method_name]
      start_index = event_definition_start(lines, index)
      end_index = event_definition_end(lines, index)
      definition_source = lines[start_index..end_index].join.chomp

      [
        method_name,
        EventDefinition.new(
          method_name: method_name,
          source: definition_source,
          line: index + 1,
        ),
      ]
    end.to_h
  end

  def event_definition_start(lines, def_index)
    index = def_index
    while index.positive? && lines[index - 1].match?(/^\s*(#.*)?$/)
      index -= 1
    end
    index
  end

  def event_definition_end(lines, def_index)
    depth = 0

    lines[def_index..].each_with_index do |line, offset|
      code = line.gsub(/#.*/, '')
      code.scan(/\b(def|if|unless|case|begin|do|while|until|for|class|module|end)\b/) do |match|
        depth += match.first == 'end' ? -1 : 1
      end

      return def_index + offset if depth.zero?
    end

    lines.length - 1
  end

  def extract_event_invocations(source, known_event_methods)
    lines = source.lines

    lines.each_with_index.flat_map do |line, index|
      method_invocations = line.to_enum(:scan, ANALYTICS_METHOD_INVOCATION_PATTERN).filter_map do
        match = Regexp.last_match
        method_name = match[:method_name]
        next unless known_event_methods.include?(method_name)

        EventInvocation.new(
          method_name: method_name,
          source: invocation_with_splatted_keyword_argument_sources(lines, index),
          line: index + 1,
        )
      end

      track_event_invocations =
        line.to_enum(:scan, ANALYTICS_TRACK_EVENT_INVOCATION_PATTERN).map do
          match = Regexp.last_match
          EventInvocation.new(
            method_name: match[:symbol_event] || match[:string_event],
            source: invocation_with_splatted_keyword_argument_sources(lines, index),
            line: index + 1,
          )
        end

      method_invocations + track_event_invocations
    end
  end

  def invocation_with_splatted_keyword_argument_sources(lines, index)
    source = invocation_source(lines, index)
    splatted_keyword_argument_sources = source
      .scan(SPLATTED_KEYWORD_ARGUMENT_PATTERN)
      .flatten
      .uniq
      .filter_map { |name| keyword_argument_source(lines, name) }

    ([source] + splatted_keyword_argument_sources).join("\n")
  end

  def keyword_argument_source(lines, name)
    helper_method_source(lines, name) || assignment_source(lines, name)
  end

  def helper_method_source(lines, name)
    lines.each_with_index do |line, index|
      next unless line.match?(/^\s*def\s+#{Regexp.escape(name)}\b/)

      return lines[index..event_definition_end(lines, index)].join.chomp
    end

    nil
  end

  def assignment_source(lines, name)
    lines.each_with_index do |line, index|
      next unless line.match?(/^\s*#{Regexp.escape(name)}\s*=/)

      return expression_source(lines, index)
    end

    nil
  end

  def expression_source(lines, index)
    source_lines = [lines[index]]
    balance = bracket_balance(lines[index])
    return source_lines.join.chomp unless balance.positive?

    current_index = index + 1
    while balance.positive? && current_index < lines.length
      source_lines << lines[current_index]
      balance += bracket_balance(lines[current_index])
      current_index += 1
    end

    source_lines.join.chomp
  end

  def invocation_source(lines, index)
    source_lines = [lines[index]]
    balance = parenthesis_balance(lines[index])
    return source_lines.join.chomp unless balance.positive?

    current_index = index + 1
    while balance.positive? && current_index < lines.length
      source_lines << lines[current_index]
      balance += parenthesis_balance(lines[current_index])
      current_index += 1
    end

    source_lines.join.chomp
  end

  def parenthesis_balance(line)
    line.count('(') - line.count(')')
  end

  def bracket_balance(line)
    line.count('({[') - line.count(')}]')
  end

  def normalize_source(source)
    source.gsub(/\s+/, ' ').strip
  end

  def first_line(source)
    source.lines.first&.strip
  end

  def format_changes(changes)
    return "No analytics event changes detected.\n" if changes.empty?

    grouped_changes = changes.group_by(&:type)
    output = +"Analytics event changes detected:\n"

    {
      new_event: 'New analytics events',
      changed_event_definition: 'Changed analytics event definitions',
      new_or_changed_invocation: 'New or changed analytics event invocations',
    }.each do |type, title|
      next unless grouped_changes[type]

      output << "\n#{title}:\n"
      grouped_changes[type].each do |change|
        output << "- #{change.file}:#{change.line} #{change.method_name}"
        output << " (#{change.source})" if change.source
        output << "\n"
      end
    end

    output
  end
end

if $PROGRAM_NAME == __FILE__
  options = AnalyticsEventChanges.parsed_options(ARGV)
  changes = AnalyticsEventChanges.detect_from_git(
    base_branch: options[:base_branch],
    source_branch: options[:source_branch],
  )

  puts AnalyticsEventChanges.format_changes(changes)
  exit(changes.empty? ? 0 : 1)
end
