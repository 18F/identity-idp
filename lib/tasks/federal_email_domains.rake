# frozen_string_literal: true

require 'faraday'
require 'csv'

DOT_GOV_DOWNLOAD_PATH = 'https://raw.githubusercontent.com/cisagov/dotgov-data/main/current-federal.csv'
namespace :federal_email_domains do
  task load_to_db: :environment do |_task, _args|
    response = Faraday.get(DOT_GOV_DOWNLOAD_PATH)

    csv = CSV.parse(response.body, col_sep: ',', headers: true)
    csv.each do |row|
      FederalEmailDomain.find_or_create_by(name: row['Domain name'])
    end
  end
end
# rake "federal_email_domains:load_to_db"
