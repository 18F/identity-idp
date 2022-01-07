# Script that parses description strings (## help) out of the Makefile
# and also uses the `make --print-data-base` output to expand out targets based on variables

expanded_makefile = `make --dry-run --print-data-base --no-builtin-rules`

# Map of lineno => [[lineno, rule]] run by printing the Makefile database
# rubocop:disable Layout/FirstArgumentIndentation
# rubocop:disable Lint/MixedRegexpCaptureTypes
expanded_targets = expanded_makefile.scan(
/\n\n(?<target>[^:]+):( (?<sources>[^\n]+))?
((#  [^\n]+)?\n?)*?
#  commands to execute \(from `Makefile', line (?<lineno>\d+)\):/m,
).map { |target, *, lineno| [lineno.to_i, target] }.
  group_by { |lineno, _target| lineno }
# rubocop:enable Lint/MixedRegexpCaptureTypes
# rubocop:enable Layout/FirstArgumentIndentation

raw_makefile = File.readlines('Makefile')

# Map of target => [comment, lineno] fom Makefile
# target might have variables like $(HOST)
target_comments = raw_makefile.map.with_index.select do |line, _lineno|
  line =~ / ## /
end.flat_map do |line, lineno|
  targets, rest = line.chomp.split(':', 2)
  _sources, comment = rest.split(' ## ')

  targets.split(' ').map { |target| [target, [comment, lineno + 2]] }
end.to_h

# Map of target => comment
cleaned_up_targets = {}

target_comments.each do |target, (comment, lineno)|
  cleaned_up_name = if target.include?('$(')
    # "tmp/$(HOST)-$(PORT).crt" into %r|tmp/.+?-.+?.crt|
    rule_regexp = Regexp.new(target.gsub(/\$\([^)]+\)/, '.+?'))

    _lineno, rule = expanded_targets[lineno].find do |_lineno, rule|
      rule_regexp.match?(rule) && !target_comments.key?(rule)
    end

    rule
  end

  cleaned_up_name ||= target

  cleaned_up_targets[cleaned_up_name] = comment
end

longest_name = cleaned_up_targets.keys.map(&:size).max

cleaned_up_targets.sort_by { |target, _comment| target }.each do |target, comment|
  puts "\033[36m#{target.ljust(longest_name)}\033[0m #{comment}"
end
