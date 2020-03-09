namespace :test do
  # Note: you probably want to `> log/test.log` to empty the test log file
  #  and then re-run tests to get a fresh view
  desc 'Scan test.log for rendered views'
  task scan_log_for_render: :environment do
    # match 'Rendered two_factor_authentication/otp_verification/show.html.erb'
    # Rendered + space + word + [/ + non-whitespace](any number of times)
    regex_finder = /Rendered\s\w*(\/\S*)*/
    results = []
    File.readlines('log/test.log').each do |line|
      results.push(line.match(regex_finder))
    end

    puts results.map(&:to_s).compact.sort.uniq
  end
end
