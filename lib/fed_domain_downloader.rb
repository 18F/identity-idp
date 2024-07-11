require 'csv'
require 'faraday'
require 'pry'


class PwnedPasswordDownloader
  DOT_GOV_DOWNLOAD_PATH = 'https://raw.githubusercontent.com/cisagov/dotgov-data/main/current-full.csv'
  
  def initialize(destination: 'tmp/fed_download_path/fed_domain_downloaded')
    @destination = destination
  end

  def dot_gov_csv_path
    response = Faraday.get(DOT_GOV_DOWNLOAD_PATH)
    response.body
  end

  def run!
    csv ||= CSV.parse(dot_gov_csv_path, col_sep: ",", headers: true)
    File.open(destination, 'wb') do |file|
      csv.each do |row|
        if row['Domain type'].include?('Federal')
        new_csv << row['Domain Name']
      end
    end
  end
end


PwnedPasswordDownloader.new.run!