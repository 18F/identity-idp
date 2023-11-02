# rubocop:disable Rails/SkipsModelValidations
require 'csv'
namespace :disposable_domains do
  task :load, %i[s3_url] => [:environment] do |_task, args|
    file = Identity::Hostdata.secrets_s3.read_file(args[:s3_url])
    csv_of_file = CSV.parse(file, headers: true)
    DisposableDomain.insert_all(csv_of_file.map(&:to_h))
  end
end
# rake "disposable_domains:load['URL_HERE']"
# rubocop:enable Rails/SkipsModelValidations
