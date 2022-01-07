require 'spec_helper'
require 'makefile_help_parser'
require 'tempfile'

RSpec.describe MakefileHelpParser do
  around do |ex|
    Tempfile.create('Makefile') do |makefile|
      @makefile = makefile.path
      makefile.rewind
      makefile << makefile_content
      makefile.close

      ex.run
    end
  end

  subject(:parser) { MakefileHelpParser.new(@makefile) }

  let(:makefile_content) do
    <<~MAKEFILE
      PORT := 3000
      HOST := localhost

      foo-$(PORT).txt bar-$(PORT).txt: ## Makes the text files
      \techo "foo" > foo-$(PORT).txt
      \techo "bar" > bar-$(PORT).txt

      foo-$(HOST).csv: ## Makes the CSV
      \techo "hi,hi" > $@

      basic.txt: ## Makes the text file
      \techo "hi" > $@
    MAKEFILE
  end

  describe '#build_expanded_targets' do
    it 'is a mapping of line numbers to targets' do
      expect(parser.build_expanded_targets).to eq(
        5 => %w[foo-3000.txt bar-3000.txt].to_set,
        9 => %w[foo-localhost.csv].to_set,
        12 => %w[basic.txt].to_set,
      )
    end
  end

  describe '#build_target_comments' do
    it 'is a mapping of target to its line number and comment' do
      expect(parser.build_target_comments).to eq(
        'foo-$(PORT).txt' => ['Makes the text files', 5],
        'bar-$(PORT).txt' => ['Makes the text files', 5],
        'foo-$(HOST).csv' => ['Makes the CSV', 9],
        'basic.txt' => ['Makes the text file', 12],
      )
    end
  end

  describe '#parse_rules' do
    it 'is the full list of rules' do
      expect(parser.parse_rules).to match_array(
        [
          MakefileHelpParser::Rule.new(
            target: 'foo-3000.txt',
            template: 'foo-$(PORT).txt',
            comment: 'Makes the text files',
          ),
          MakefileHelpParser::Rule.new(
            target: 'bar-3000.txt',
            template: 'bar-$(PORT).txt',
            comment: 'Makes the text files',
          ),
          MakefileHelpParser::Rule.new(
            target: 'foo-localhost.csv',
            template: 'foo-$(HOST).csv',
            comment: 'Makes the CSV',
          ),
          MakefileHelpParser::Rule.new(
            target: 'basic.txt',
            comment: 'Makes the text file',
          ),
        ],
      )
    end
  end
end
