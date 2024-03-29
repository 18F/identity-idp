# frozen_string_literal: true

namespace :test do
  # Use `> log/test.log` to empty test.log before re-running tests to get an accurate list
  # Note you must run tests with `COVERAGE=true` to generate scannable logs.
  desc 'Scan test.log for rendered views and show gaps in test coverage'
  task scan_log_for_view_coverage: :environment do
    # match lines like 'Rendered two_factor_authentication/otp_verification/show.html.erb'
    # Rendered + space + word + [/ + non-whitespace](any number of times).html(.erb|'')
    regex_finder = %r{Rendered\s\w*(/\S*)*\.html(\.erb|)}
    results = []
    File.readlines('log/test.log').each do |line|
      results.push(line.match(regex_finder))
    end

    results = results.map { |r| r.to_s.remove('Rendered ') }
    results = results.reject(&:empty?).sort.uniq

    puts "== #{results.size} rendered (covered) views present in test.log =="

    # Gets all .html, and .html.erb views
    all_views = Dir.glob('app/views/**/*.{html,html.erb}*')
    all_views = all_views.map { |v| v.remove('app/views/') }.sort.uniq
    puts "== #{all_views.size} total views in the app =="

    # Get total - covered
    uncovered_views = all_views.reject { |v| results.include?(v) }.sort.uniq
    puts "== #{uncovered_views.size} uncovered views: =="
    puts uncovered_views
  end
end
