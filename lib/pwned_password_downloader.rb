#!/usr/bin/env ruby
require 'fileutils'
require 'thread'
require 'net/http/persistent'
require 'ruby-progressbar'

class PwnedPasswordDownload
  attr_reader :destination,
              :num_threads,
              :verbose,
              :keep_threshold # only keep password hashes that have uses bigger than this

  def initialize(
    destination: 'tmp/pwned',
    num_threads: 64,
    verbose: false,
    keep_threshold: 10_000
  )
    @destination = destination
    @num_threads = num_threads
    @verbose = verbose
    @keep_threshold = keep_threshold
  end

  def verbose?
    !!@verbose
  end

  def run!
    queue = Queue.new

    ('00000'.to_i(16)..'FFFFF'.to_i(16)).each do |prefix_num|
      queue << prefix_num.to_s(16).upcase.rjust(5, '0')
    end

    bar = ProgressBar.create(
      title: 'Downloading...',
      total: queue.size,
      format: '[ %t ] %p%% %B %a (%E)',
    )

    FileUtils.mkdir_p(destination)

    threads = num_threads.times.map do
      Thread.new do |thread_id|
        net_http = Net::HTTP::Persistent.new(name: "thread_id_#{thread_id}")

        while (prefix = queue.pop)
          if already_downloaded?(prefix)
            bar.log("#{prefix} SKIP, already downloaded") if verbose?
          else
            write_one(
              prefix:,
              content: download_one(prefix:, net_http:),
            )
            bar.log("#{prefix} DONE") if verbose?
          end
          bar.increment
        end
      ensure
        net_http.shutdown
      end
    end

    while !queue.empty?
      sleep 3
    end

    bar.log("DONE") if verbose?
  ensure
    bar.stop
  end

  def already_downloaded?(prefix)
    File.exist?(File.join(destination, prefix))
  end

  # @return [String]
  def download_one(prefix:, net_http: Net::HTTP::Persistent.new, keep: keep_threshold)
    net_http.
      request(URI("https://api.pwnedpasswords.com/range/#{prefix}")).
      body.
      each_line(chomp: true).
      select { |line| line.split(':', 2).last.to_i >= keep }.
      map do |line|
        "#{prefix}#{line}"
      end.
      join("\n")
  end

  def write_one(prefix:, content:)
    File.open(File.join(destination, prefix), 'w') do |f|
      f.write(content)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  PwnedPasswordDownload.new.run!
end
