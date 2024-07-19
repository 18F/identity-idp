# frozen_string_literal: true

require 'csv'
require 'faraday'
require 'pry'
require 'fileutils'

class FedEmailDomainDownloader
  attr_reader :destination

  DOT_GOV_DOWNLOAD_PATH = 'https://raw.githubusercontent.com/cisagov/dotgov-data/main/current-full.csv'

  def initialize(destination: 'tmp/fed_download_path')
    @destination = destination
  end

  def dot_gov_csv_path
    response = Faraday.get(DOT_GOV_DOWNLOAD_PATH)
    response.body
  end

  def run!
    FileUtils.mkdir_p(destination)
    csv ||= CSV.parse(dot_gov_csv_path, col_sep: ',', headers: true)
    File.open("#{destination}/fed_email_domains.txt", 'w') do |file|
      csv.each do |row|
        if row['Domain type'].include?('Federal')
          file.write("#{row['Domain name']}\n")
        end
      end
    end
  end
end

FedEmailDomainDownloader.new.run!
