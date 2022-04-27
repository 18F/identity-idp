require 'rails_helper'
require_relative '../../scripts/changelog_check'

RSpec.describe 'scripts/changelog_check' do
  git_fixtures = YAML.safe_load(File.read(File.expand_path('spec/fixtures/git_log_changelog.yml')))

  describe '#build_changelog' do
    it 'builds a git log into structured changelog objects' do
      git_log = git_fixtures.values.pluck('commit_log').join("\n")
      changelog_entries = generate_changelog(git_log)
      expect(changelog_entries.length).to eq 3
      fixture_and_changelog = git_fixtures.values.filter do |x|
        x['category'].present?
      end.zip(changelog_entries)

      fixture_and_changelog.each do |fixture, changelog|
        expect(fixture['category']).to eq changelog.category
        expect(fixture['subcategory']).to eq changelog.subcategory
        expect(fixture['pr_number']).to eq changelog.pr_number
        expect(fixture['change']).to eq changelog.change
      end
    end

    it 'skips commits with [skip changelog]' do
      commits = [
        git_fixtures['squashed_commit_with_one_commit'],
        git_fixtures['squashed_commit_with_skip'],
      ]
      git_log = commits.pluck('commit_log').join("\n")
      changelog = generate_changelog(git_log)
      expect(changelog.length).to eq 1

      expect(commits.first['category']).to eq changelog.first.category
      expect(commits.first['subcategory']).to eq changelog.first.subcategory
      expect(commits.first['pr_number']).to eq changelog.first.pr_number
      expect(commits.first['change']).to eq changelog.first.change
    end
  end

  describe '#build_structured_git_log' do
    it 'builds a git log into structured objects' do
      git_fixtures.values.each do |commit_fixture|
        commits = build_structured_git_log(commit_fixture['commit_log'])
        expect(commits.length).to eq 1
        expect(commits.first.title).to eq commit_fixture['title']
        expect(commits.first.commit_messages).to eq commit_fixture['commit_messages']
      end
    end
  end

  describe '#generate_invalid_changes' do
    it 'returns changelog entries without a valid structure' do
      commits = [
        git_fixtures['squashed_commit_invalid'],
        git_fixtures['squashed_commit_with_one_commit'],
        git_fixtures['squashed_commit_with_skip'],
      ]
      git_log = commits.pluck('commit_log').join("\n")
      changes = generate_invalid_changes(git_log)

      expect(changes.length).to eq 1
      expect(commits.first['title']).to eq changes.first
    end
  end

  describe '#format_changelog' do
    it 'returns changelog entries without a valid structure' do
      commits = [
        git_fixtures['squashed_commit_invalid'],
        git_fixtures['squashed_commit_with_one_commit'],
        git_fixtures['squashed_commit_with_skip'],
        git_fixtures['squashed_commit_with_duplicate_pr'],
        git_fixtures['squashed_commit_with_multiple_commits'],
      ]
      git_log = commits.pluck('commit_log').join("\n")
      changelogs = generate_changelog(git_log)
      formatted_changelog = format_changelog(changelogs)

      expect(formatted_changelog).to eq <<~CHANGELOG.chomp
        ## Improvements
        - Webauthn: Provide better error flow for users who may not be able to leverage webauthn (LG-5515) ([#5976](https://github.com/18F/identity-idp/pull/5976))

        ## Internal
        - Security: Upgrade Rails to patch vulnerability ([#6041](https://github.com/18F/identity-idp/pull/6041), [#6042](https://github.com/18F/identity-idp/pull/6042))
      CHANGELOG
    end
  end

  describe '#generate_changelog' do
    it 'capitalizes subcategory and capitalizes first letter of change description' do
      git_log = <<~COMMIT
        title: Add LOGIN_TASK_LOG_LEVEL env var (#6037)
        body:- Lets us set log level to minimize STDOUT output
          from Identity::Hostdata (downloading files from S3, etc)

        * changelog: Improvements, authentication, provide better authentication (LG-4515)
        DELIMITER
      COMMIT

      changelogs = generate_changelog(git_log)

      expect(changelogs.first.subcategory).to eq('Authentication')
      expect(changelogs.first.change).to start_with('P')
    end
  end
end
