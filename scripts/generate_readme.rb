# frozen_string_literal: true

require 'optparse'

class GenerateReadme
  attr_reader :docs_dir

  def initialize(docs_dir:)
    @docs_dir = docs_dir
  end

  # @return [String]
  def build
    <<~MARKDOWN
      # Login.gov Identity Provider (IdP)

      Login.gov is the public's one account for government. Use one account and password for secure, private access to participating government agencies.

      This repository contains the core code base and documentation for the identity management system powering secure.login.gov.

      **This file is auto-generated**. Run `make README.md` to regenerate its contents.

      ## Getting Started

      Refer to the [_Local Development_ documentation](./docs/local-development.md) to learn how to set up your environment for local development.

      ## Guides

      - [The Contributing Guide](CONTRIBUTING.md) includes basic guidelines around pull requests, commit messages, and the code review process.
      - [The Login.gov Handbook](https://handbook.login.gov/) describes organizational practices, including process runbooks and team structures.

      ## Documentation

      #{table_of_contents}
    MARKDOWN
  end

  def table_of_contents
    docs_and_titles.map do |(title, path)|
      "- [#{title}](#{path})"
    end.join("\n")
  end

  # @return [Array<Array(String, String)>] a list of (title, path) tuples
  def docs_and_titles
    Dir.glob("#{docs_dir}/**/*.md").map do |path|
      title = guess_title(File.read(path))
      [title, path]
    end.sort_by(&:first)
  end

  # Guesses title from the first markdown heading in a file
  def guess_title(content)
    content.lines(chomp: true).each do |line|
      capture = line.match(/#+ (?<heading>.+)$/)
      break capture[:heading] if capture
    end || 'NO_TITLE'
  end

  def self.parse!(argv)
    options = {}

    parser = OptionParser.new do |opts|
      opts.banner = <<~TXT
        #{$PROGRAM_NAME} --docs-dir DOCS

        Generates a README.md by indexing into the given docs directory
      TXT

      opts.on('--docs-dir DIR', 'the directory to check for documents') do |dir|
        options[:docs_dir] = dir.chomp('/')
      end

      opts.on('--help') do
        puts opts
        exit 0
      end
    end

    parser.parse!(argv)

    if !options[:docs_dir]
      puts parser
      exit 1
    end

    options
  end
end

if __FILE__ == $PROGRAM_NAME
  options = GenerateReadme.parse!(ARGV)

  puts GenerateReadme.new(**options).build
end
