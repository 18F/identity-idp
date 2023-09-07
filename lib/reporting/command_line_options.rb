require 'reporting/cloudwatch_query_time_slice'

module Reporting
  class CommandLineOptions
    # rubocop:disable Rails/Exit
    # @return [Hash]
    def parse!(argv, out: STDOUT, require_issuer: true)
      date = nil
      issuers = []
      verbose = false
      progress = true
      period = nil
      slice = nil
      threads = nil

      program_name = Pathname.new($PROGRAM_NAME).relative_path_from(__dir__)

      # rubocop:disable Metrics/BlockLength
      parser = OptionParser.new do |opts|
        opts.banner = <<~TXT
          Usage:

          #{program_name} --date YYYY-MM-DD --issuer ISSUER

          Options:
        TXT

        opts.on('--date=DATE', 'date to run the report in YYYY-MM-DD format') do |date_v|
          date = Date.parse(date_v)
          period = :day
        end

        opts.on('--week=DATE', <<~STR.squish) do |date_v|
          run the report for the week (Sun-Sat) that includes the date in YYYY-MM-DD format
        STR
          date = Date.parse(date_v)
          period = :week
        end

        opts.on('--month=DATE', <<~STR.squish) do |date_v|
          run the report for the month that includes the date in YYYY-MM-DD format.
          changes defaults to `--threads 10` and `--slice 1 hour` to reduce likelihood of timeout
        STR
          date = Date.parse(date_v)
          period = :month

          slice ||= 1.hour
          threads ||= 10
        end

        opts.on('--issuer=ISSUER') do |issuer_v|
          issuers << issuer_v
        end

        opts.on('--[no-]verbose', 'log details STDERR, default to off') do |verbose_v|
          verbose = verbose_v
        end

        opts.on('--[no-]progress', 'shows a progress bar or hides it, defaults on') do |progress_v|
          progress = progress_v
        end

        opts.on(
          '--slice SLICE',
          '(optional) query slice size duration, defaults to 3h',
        ) do |slice_v|
          slice = CloudwatchQueryTimeSlice.parse_duration(slice_v)
        end

        opts.on(
          '--threads THREADS',
          '(optional) number of threads between 1 and 30 inclusive, defaults to 5. ',
        ) do |threads_v|
          if !threads_v.to_i.between?(1, 30)
            raise StandardError.new(
              'Number of threads must be between 1 and 30 inclusive',
            )
          end

          threads = threads_v.to_i
        end

        opts.on('-h', '--help') do
          out.puts opts
          exit 1
        end
      end
      # rubocop:enable Metrics/BlockLength

      parser.parse!(argv)

      if !date || (require_issuer && issuers.empty?)
        out.puts parser
        exit 1
      else
        {
          time_range: time_range(date:, period:),
          issuers: issuers,
          verbose: verbose,
          progress: progress,
          slice: slice || 3.hours,
          threads: threads || 5,
        }
      end
    end
    # rubocop:enable Rails/Exit

    # @param [Date]
    # @return [Range<Time>]
    def time_range(date:, period:)
      orig_beginning_of_week = Date.beginning_of_week
      Date.beginning_of_week = :sunday

      utc = date.in_time_zone('UTC')

      case period
      when :day
        utc.all_day
      when :week
        utc.all_week
      when :month
        utc.all_month
      else
        raise "unknown period=#{period}"
      end
    ensure
      Date.beginning_of_week = orig_beginning_of_week
    end
  end
end
