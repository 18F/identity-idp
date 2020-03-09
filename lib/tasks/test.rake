namespace :test do
  # Note: you probably want to `> log/test.log` to empty the test log file
  #  and then re-run tests to get a fresh view
  desc 'Scan test.log for rendered views'
  task scan_log_for_render: :environment do
    test_log = File.read('log/test.log')
    # Rendered + space + word + [/ + non-whitespace](any number of times)
    regex_finder = /Rendered\s\w*(\/\S*)*/
    results = []

    test_log.each_line do |li|
      results.push(li.match(regex_finder))
    end

    puts results.map(&:to_s).compact.sort.uniq
  end
end
