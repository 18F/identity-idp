require 'open3'

# Parses comment strings (## help) out of the Makefile
# and also uses the `make --print-data-base` output to expand out targets based on variables
class MakefileHelpParser
  Rule = Struct.new(:target, :template, :comment, keyword_init: true)

  attr_reader :makefile_path

  def initialize(makefile_path = 'Makefile')
    @makefile_path = makefile_path
  end

  # @return [String]
  def pretty_rules
    rules = parse_rules

    longest_target = rules.map { |r| r.target.size }.max
    longest_template = rules.map { |r| r.template&.size.to_i }.max

    rules.sort_by(&:target).map do |rule|
      [
        blue(rule.target.ljust(longest_target)),
        (rule.template || '').ljust(longest_template),
        rule.comment,
      ].join(' ')
    end.join("\n")
  end

  def blue(str)
    "\033[36m#{str}\033[0m"
  end

  # @return [Array<Rule>]
  def parse_rules
    target_comments = build_target_comments
    expanded_targets = build_expanded_targets

    target_comments.map do |target, (comment, lineno)|
      if target.include?('$(')
        Rule.new(
          target: matching_target(
            lineno:,
            template: target,
            target_comments:,
            expanded_targets:,
          ),
          template: target,
          comment:,
        )
      else
        Rule.new(
          target:,
          comment:,
        )
      end
    end
  end

  # @param [Integer] lineno line number in original Makefile
  # @param [String] template like "tmp/$(HOST)-$(PORT).crt"
  # @param [Hash<String, Array(String, Integer)>] target_comments (see #build_target_comments)
  # @return [Hash<String, Array(String, Integer)>] expanded_targets (see #build_expanded_targets)
  # @return [String, nil] a target that matches it like "tmp/localhost-3000.crt"
  def matching_target(lineno:, template:, target_comments:, expanded_targets:)
    # "tmp/$(HOST)-$(PORT).crt" into %r|tmp/.+?-.+?.crt|
    rule_regexp = Regexp.new(template.gsub(/\$\([^)]+\)/, '.+?'))

    expanded_targets[lineno].find do |rule|
      rule_regexp.match?(rule) && !target_comments.key?(rule)
    end
  end

  # Map of target => [comment, lineno]
  # target might have variables like $(HOST)
  # @return [Hash<String, Array(String, Integer)>]
  def build_target_comments
    raw_makefile = File.readlines(makefile_path)

    raw_makefile.map.with_index.select do |line, _lineno|
      line.include?(' ## ')
    end.flat_map do |line, lineno|
      targets, rest = line.chomp.split(':', 2)
      _sources, comment = rest.split(' ## ')

      targets.split(' ').map { |target| [target, [comment, lineno + 2]] }
    end.to_h
  end

  # Maps line numbers to expanded targets
  # @return [Hash<Integer, Set<String>>]
  def build_expanded_targets
    expanded_makefile, _stderr, _status = Open3.capture3(
      'make', '-f', makefile_path, '--dry-run', '--print-data-base'
    )

    targets = Hash.new { |h, k| h[k] = Set.new }

    expanded_makefile.split("\n\n").map do |stanza|
      m = stanza.match(/^#  .* \(from [`']#{makefile_path}', line (?<lineno>\d+)\):$/)
      [stanza, m && m[:lineno].to_i]
    end.
      select { |_stanza, lineno| lineno }.
      each do |stanza, lineno|
        target = stanza.split("\n").first.split(':').first

        targets[lineno] << target
      end

    targets
  end
end

# rubocop:disable Rails/Output
if $PROGRAM_NAME == __FILE__
  puts MakefileHelpParser.new.pretty_rules
end
# rubocop:enable Rails/Output
