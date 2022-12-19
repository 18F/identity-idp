#!/usr/bin/env ruby
require 'open3'
require 'optparse'

CHANGELOG_REGEX =
  %r{^(?:\* )?[cC]hangelog: ?(?<category>[\w -/]{2,}), ?(?<subcategory>[\w -]{2,}), ?(?<change>.+)$}
CATEGORIES = [
  'User-Facing Improvements',
  'Improvements', # Temporary for transitional period
  'Bug Fixes',
  'Internal',
  'Upcoming Features',
]
MAX_CATEGORY_DISTANCE = 3
SKIP_CHANGELOG_MESSAGE = '[skip changelog]'
DEPENDABOT_COMMIT_MESSAGE = 'Signed-off-by: dependabot[bot] <support@github.com>'
SECURITY_CHANGELOG = {
  category: 'Internal',
  subcategory: 'Dependencies',
  change: 'Update dependencies to resolve security advisories',
}.freeze

SquashedCommit = Struct.new(:title, :commit_messages, keyword_init: true)
ChangelogEntry = Struct.new(:category, :subcategory, :change, :pr_number, keyword_init: true)
CategoryDistance = Struct.new(:category, :distance)

# A valid entry has a line in a commit message in the form of:
# changelog: CATEGORY, SUBCATEGORY, CHANGE_DESCRIPTION
def build_changelog(line)
  if line == DEPENDABOT_COMMIT_MESSAGE
    SECURITY_CHANGELOG
  else
    CHANGELOG_REGEX.match(line)
  end
end

def build_changelog_from_commit(commit)
  [*commit.commit_messages, commit.title].
    lazy.
    map { |message| build_changelog(message) }.
    find(&:itself)
end

def get_git_log(base_branch, source_branch)
  format = '--pretty=title: %s%nbody:%b%nDELIMITER'
  log, status = Open3.capture2(
    'git', 'log', format, "#{base_branch}..#{source_branch}"
  )

  raise 'git log failed' unless status.success?
  log
end

# Transforms a formatted git log into structured objects.
# The git format ends up printing a single commit as:
#
# title: Remove unused IdV controller view (#5922)
# body:**Why**: Because it's unused.
# * Add changelog, change constant name
# DELIMITER
# The string is first split on DELIMITER, and then the body is split into
# individual lines.
def build_structured_git_log(git_log)
  git_log.strip.split('DELIMITER').map do |commit|
    commit.split("\nbody:").map do |commit_message_lines|
      commit_message_lines.split(%r{[\r\n]}).filter { |line| line != '' }
    end
  end.map do |title_and_commit_messages|
    title = title_and_commit_messages.first.first.delete_prefix('title: ')
    messages = title_and_commit_messages[1]
    SquashedCommit.new(
      title: title,
      commit_messages: messages,
    )
  end
end

def commit_messages_contain_skip_changelog?(base_branch, source_branch)
  log, status = Open3.capture2(
    'git', 'log', '--pretty=\'%B\'', "#{base_branch}..#{source_branch}"
  )
  raise 'git log failed' unless status.success?

  log.include?(SKIP_CHANGELOG_MESSAGE)
end

def generate_invalid_changes(git_log)
  log = build_structured_git_log(git_log)
  log.reject do |commit|
    commit.title.include?(SKIP_CHANGELOG_MESSAGE) ||
      commit.commit_messages.any? { |message| message.include?(SKIP_CHANGELOG_MESSAGE) } ||
      build_changelog_from_commit(commit)
  end.map(&:title)
end

def closest_change_category(change)
  category = CATEGORIES.
    map do |category|
      CategoryDistance.new(
        category,
        DidYouMean::Levenshtein.distance(change[:category], category),
      )
    end.
    filter { |category_distance| category_distance.distance <= MAX_CATEGORY_DISTANCE }.
    max { |category_distance| category_distance.distance }&.
    category

  # Temporarily normalize legacy category in transitional period
  category = 'User-Facing Improvements' if category == 'Improvements'
  category
end

# Get the last valid changelog line for every Pull Request and tie it to the commit subject.
# Each PR should be squashed, which results in every PR being one commit. The commit messages
# in a squashed PR are concatencated with a leading "*" for each commit. Example:
#
# commit b7cc1cdaf697decb9908cb125538e75bddc46489
# Author: IDP Committer <idp.committer@gsa.gov>
# Date:   Wed Feb 2 09:14:29 2022 -0500
#
#     LG-9998: Update Authentication (#9999)
#
#     * Update Authentication commit #1
#
#     changelog: Authentication: Updating Authentication (LG-9998)
#
#     * Authentication commit #2
def generate_changelog(git_log)
  log = build_structured_git_log(git_log)

  changelog_entries = []
  log.each do |item|
    # Skip this commit if the skip changelog message appears
    next if item.title.include?(SKIP_CHANGELOG_MESSAGE)
    next if item.commit_messages.any? { |message| message.include?(SKIP_CHANGELOG_MESSAGE) }
    change = build_changelog_from_commit(item)
    next unless change
    category = closest_change_category(change)
    next unless category

    pr_number = %r{\(#(?<pr>\d+)\)}.match(item[:title])

    changelog_entry = ChangelogEntry.new(
      category: category,
      subcategory: change[:subcategory],
      pr_number: pr_number&.named_captures&.fetch('pr'),
      change: change[:change].sub(/./, &:upcase),
    )

    changelog_entries << changelog_entry
  end

  changelog_entries
end

# Turns a list of ChangeLogEntry objects into a formatted string that is fit to be pasted
# directly into release notes.
# Entries with the same category and change are grouped into one changelog line so that we can
# support multi-PR changes.
def format_changelog(changelog_entries)
  changelog_entries = changelog_entries.
    sort_by(&:subcategory).
    group_by { |entry| [entry.category, entry.change] }

  changelog = ''
  CATEGORIES.each do |category|
    category_changes = changelog_entries.
      filter { |(changelog_category, _change), _changes| changelog_category == category }

    next if category_changes.empty?
    changelog.concat("## #{category}\n")
    category_changes.each do |group, entries|
      change = entries.first.change
      subcategory = entries.first.subcategory
      pr_numbers = entries.map(&:pr_number).compact.sort
      if pr_numbers.count > 0
        formatted_pr_numbers = pr_numbers.map do |number|
          "[##{number}](https://github.com/18F/identity-idp/pull/#{number})"
        end.join(', ')
        formatted_pr_numbers = " (#{formatted_pr_numbers})"
      else
        formatted_pr_numbers = ''
      end

      changelog.concat("- #{subcategory}: #{change}#{formatted_pr_numbers}\n")
    end

    changelog.concat("\n")
  end

  changelog.strip
end

def parsed_options(args)
  options = { base_branch: 'main', source_branch: 'HEAD' }
  basename = File.basename($0)

  optparse = OptionParser.new do |opts|
    opts.banner = <<-EOM
      usage: #{basename} -s my-feature-branch [OPTIONS]

    EOM
    opts.on('-h', '--help', 'Display this message') do
      warn opts
      exit
    end

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
  end

  optparse.parse!(args)
  options
end

def main(args)
  options = parsed_options(args)

  abort(optparse.help) if options[:source_branch].nil?

  git_log = get_git_log(options[:base_branch], options[:source_branch])
  changelog_entries = generate_changelog(git_log)
  invalid_changelog_entries = generate_invalid_changes(git_log)

  skip_check = commit_messages_contain_skip_changelog?(
    options[:base_branch],
    options[:source_branch],
  )

  if skip_check || changelog_entries.count > 0
    formatted_changelog = format_changelog(changelog_entries)
    puts format_changelog(changelog_entries) if formatted_changelog.length > 0
    if invalid_changelog_entries.count > 0
      puts "\n!!! Invalid Changelog Entries !!!"
      puts invalid_changelog_entries.join("\n")
    end

    exit 0
  else
    warn(
      <<~ERROR,
        A valid changelog line was not found.
        A commit message should contain a line in the form of:

        changelog: CATEGORY, SUBCATEGORY, CHANGE_DESCRIPTION

        example:
        changelog: User-Facing Improvements, WebAuthn, Improve error flow for WebAuthn (LG-5515)

        categories:
        #{CATEGORIES.map { |category| "- #{category}" }.join("\n")}

        Include "[skip changelog]" in a commit message to bypass this check.

        Note: the changelog message must be separated from any other commit message by a blank line.
      ERROR
    )

    exit 1
  end
end

main(ARGV) if __FILE__ == $0
