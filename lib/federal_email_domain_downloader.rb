# frozen_string_literal: true
require 'csv'
require 'faraday'

class FederalEmailDomainDownloader
  DOT_GOV_DOWNLOAD_PATH = 'https://raw.githubusercontent.com/cisagov/dotgov-data/main/current-federal.csv'

  def dot_gov_csv
    response = Faraday.get(DOT_GOV_DOWNLOAD_PATH)
    response.body
  end

  def load_to_db!
    csv ||= CSV.parse(dot_gov_csv, col_sep: ',', headers: true)
    csv.each do |row|
      ::FederalEmailDomain.insert(names.map { |name| { name: row['Domain name']} })
    end
  end
end
