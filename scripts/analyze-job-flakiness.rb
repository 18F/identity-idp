# frozen_string_literal: true

require 'csv'
require 'json'
require 'net/http'
require 'uri'

PROJECT_ID = (ENV['CI_PROJECT_ID']&.to_i || 19).freeze
ACCESS_TOKEN = ENV['CI_JOB_TOKEN']
MAX_AGE_IN_SECONDS = (ENV['MAX_AGE_IN_SECONDS']&.to_i || (24 * 60 * 60)).freeze
NOT_BEFORE = (Time.now - MAX_AGE_IN_SECONDS).utc.strftime('%Y-%m-%dT%H:%M:%SZ').freeze
BRANCH = ENV['BRANCH_TO_INSPECT'] || 'main'

STATUS_SUCCESS = 'success'
STATUS_FAILED = 'failed'

raise 'Must specify CI_JOB_TOKEN' if ACCESS_TOKEN.nil?

def get_jobs_from_api(ref: nil, statuses: nil, &block)
  page = 1
  stop_processing = false

  url = URI.parse("https://gitlab.login.gov/api/v4/projects/#{PROJECT_ID.to_i}/jobs")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = (url.scheme == 'https')

  until stop_processing
    url.query = [
      "page=#{page}",
      'per_page=100',
      *Array(statuses).map { |status| "scope[]=#{status}" },
    ].compact.join('&')

    request = Net::HTTP::Get.new(url.request_uri)
    request['PRIVATE-TOKEN'] = ACCESS_TOKEN

    warn "📡 Fetch #{url}"

    response = http.request(request)

    raise "Failed: #{response.code}" if response.code.to_i != 200

    JSON.parse(response.body).each do |job|
      next if !ref.nil? && job['ref'] != ref

      result = block.call(job)

      if result == false
        stop_processing = true
        break
      end
    end

    break if stop_processing

    page += 1
  end
end

def get_jobs_from_stdin(ref: nil, statuses: nil, &block)
  STDIN.each_line do |line|
    next if line == ''

    job = begin
      JSON.parse(line)
    rescue
      nil
    end

    next if job.nil?
    next if !ref.nil? && job['ref'] != ref
    next if !statuses.nil? && !statuses.include?(job['status'])

    block.call(job)
  end
end

def get_jobs(ref:, statuses:, &block)
  if STDIN.tty? || STDIN.eof?
    warn '📕 Reading job data from API'
    get_jobs_from_api(ref:, statuses:, &block)
  else
    warn '📕 Reading job data from stdin'
    get_jobs_from_stdin(ref:, statuses:, &block)
  end
end

warn "🔍 Looking for jobs between #{NOT_BEFORE} and now"

jobs_by_commit = Hash.new { |hash, key| hash[key] = [] }

get_jobs(ref: BRANCH, statuses: ['success', 'failed']) do |job|
  next false if job['created_at'] < NOT_BEFORE
  jobs_by_commit[job['commit']['id']] << job
end

warn "ℹ️  Found jobs for #{jobs_by_commit.length} commits on #{BRANCH}"

flaky_jobs = []

jobs_by_commit.each do |commit_sha, jobs|
  jobs_by_name = Hash.new { |hash, key| hash[key] = [] }

  jobs.each do |job|
    jobs_by_name[job['name']] << job
  end

  jobs_by_name.each do |job_name, jobs|
    success_count = jobs.count { |job| job['status'] == STATUS_SUCCESS }
    failure_count = jobs
      .filter { |job| job['failure_reason'] == 'script_failure' }
      .count { |job| job['status'] == STATUS_FAILED }

    looks_flaky = success_count > 0 && failure_count > 0
    if looks_flaky
      flaky_jobs << {
        commit_sha:,
        job_name:,
        success_count:,
        failure_count:,
      }
    end
  end
end

if flaky_jobs.empty?
  warn "🦄 No flaky jobs found since #{NOT_BEFORE} on #{BRANCH}"
  exit
end

warn "🦨 Found #{flaky_jobs.length} flaky-looking job(s) since #{NOT_BEFORE} on #{BRANCH}\n"

CSV do |csv|
  flaky_jobs.each_with_index do |row, index|
    csv << row.keys if index == 0
    csv << row.values
  end
end
