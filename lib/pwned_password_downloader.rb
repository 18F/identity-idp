#!/usr/bin/env ruby
require 'fileutils'
require 'net/http/persistent'
require 'retries'
require 'ruby-progressbar'

class PwnedPasswordDownloader
  attr_reader :destination,
              :num_threads,
              :keep_threshold

  RANGE_API_ROOT = 'https://api.pwnedpasswords.com/range/'
  SHA1_LENGTH = 40
  HASH_PREFIX_LENGTH = 5
  OCCURRENCE_OFFSET = SHA1_LENGTH - HASH_PREFIX_LENGTH + ':'.length

  def initialize(
    destination: 'tmp/pwned',
    num_threads: 64,
    keep_threshold: 30
  )
    @destination = destination
    @num_threads = num_threads
    @keep_threshold = keep_threshold
  end

  def run!(start: '00000', finish: 'FFFFF')
    (start.to_i(16)..finish.to_i(16)).each do |prefix_num|
      queue << prefix_num.to_s(16).upcase.rjust(5, '0')
    end

    FileUtils.mkdir_p(destination)

    num_threads.times.map do
      Thread.new do |thread_id|
        net_http = Net::HTTP::Persistent.new(name: "thread_id_#{thread_id}")

        while (prefix = queue.pop)
          if already_downloaded?(prefix)
            progress_bar.increment
            next
          end

          begin
            write_one(
              prefix:,
              content: with_retries(max_tries: 5, rescue: Socket::ResolutionError) do
                download_one(prefix:, net_http:)
              end,
            )
          rescue
            queue << prefix
          else
            progress_bar.increment
          end
        end
      ensure
        net_http.shutdown
      end
    end

    wait_for_progress until queue.empty?
  ensure
    progress_bar.stop
  end

  def queue
    @queue ||= Queue.new
  end

  def wait_for_progress
    sleep 3
  end

  def progress_bar
    @progress_bar ||= ProgressBar.create(
      title: 'Downloading...',
      total: queue.size,
      format: '[ %t ] %p%% %B %a (%E)',
    )
  end

  def already_downloaded?(prefix)
    File.exist?(File.join(destination, prefix))
  end

  # @return [String]
  def download_one(prefix:, net_http: Net::HTTP::Persistent.new, keep: keep_threshold)
    net_http.
      request(URI.join(RANGE_API_ROOT, prefix)).
      body.
      each_line(chomp: true).
      select { |line| line[OCCURRENCE_OFFSET..].to_i >= keep }.
      reduce('') { |result, line| result + "#{prefix}#{line}\n" }
  end

  def write_one(prefix:, content:)
    File.open(File.join(destination, prefix), 'w') do |f|
      f.write(content)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  PwnedPasswordDownloader.new.run!
end
