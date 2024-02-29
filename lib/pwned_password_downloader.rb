#!/usr/bin/env ruby
require 'fileutils'
require 'net/http/persistent'
require 'retries'
require 'ruby-progressbar'

class PwnedPasswordDownloader
  attr_reader :destination,
              :num_threads,
              :keep_threshold

  def initialize(
    destination: 'tmp/pwned',
    num_threads: 64,
    keep_threshold: 30
  )
    @destination = destination
    @num_threads = num_threads
    @keep_threshold = keep_threshold
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

    num_threads.times.map do
      Thread.new do |thread_id|
        net_http = Net::HTTP::Persistent.new(name: "thread_id_#{thread_id}")

        while (prefix = queue.pop)
          if already_downloaded?(prefix)
            bar.increment
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
            bar.increment
          end
        end
      ensure
        net_http.shutdown
      end
    end

    sleep 3 until queue.empty?
  ensure
    bar.stop
  end

  def already_downloaded?(prefix)
    File.exist?(File.join(destination, prefix))
  end

  # @return [String]
  def download_one(prefix:, net_http: Net::HTTP::Persistent.new, keep: keep_threshold)
    net_http.
      request("https://api.pwnedpasswords.com/range/#{prefix}").
      body.
      each_line(chomp: true).
      select { |line| line[36..].to_i >= keep }.
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
