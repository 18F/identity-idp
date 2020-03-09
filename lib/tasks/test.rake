namespace :test do
  # Use `> log/test.log` to empty test.log before re-running tests to get an accurate list
  # Note you must run tests with `COVERAGE=true` to generate scannable logs.
  desc 'Scan test.log for rendered views'
  task scan_log_for_render: :environment do
    # match 'Rendered two_factor_authentication/otp_verification/show.html.erb'
    # Rendered + space + word + [/ + non-whitespace](any number of times)
    regex_finder = %r|Rendered\s\w*(/\S*)*|
    results = []
    File.readlines('log/test.log').each do |line|
      results.push(line.match(regex_finder))
    end

    puts results.map(&:to_s).compact.sort.uniq
  end
end
