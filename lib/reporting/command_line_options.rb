module Reporting
  class CommandLineOptions
    # rubocop:disable Rails/Exit
    # @return [Hash]
    def parse!(argv, out: STDOUT)
      date = nil
      issuer = nil
      verbose = false
      progress = true

      program_name = Pathname.new($PROGRAM_NAME).relative_path_from(__dir__)

      parser = OptionParser.new do |opts|
        opts.banner = <<~TXT
          Usage:

          #{program_name} --date YYYY-MM-DD --issuer ISSUER

          Options:
        TXT

        opts.on('--date=DATE', 'date to run the report in YYYY-MM-DD format') do |date_v|
          date = Date.parse(date_v)
        end

        opts.on('--issuer=ISSUER') do |issuer_v|
          issuer = issuer_v
        end

        opts.on('--[no-]verbose', 'log details STDERR, default to off') do |verbose_v|
          verbose = verbose_v
        end

        opts.on('--[no-]progress', 'shows a progress bar or hides it, defaults on') do |progress_v|
          progress = progress_v
        end

        opts.on('-h', '--help') do
          out.puts opts
          exit 1
        end
      end

      parser.parse!(argv)

      if !date || !issuer
        out.puts parser
        exit 1
      end

      {
        date: date,
        issuer: issuer,
        verbose: verbose,
        progress: progress,
      }
    end
    # rubocop:enable Rails/Exit
  end
end
