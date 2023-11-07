# rubocop:disable Rails/SkipsModelValidations
require 'csv'
namespace :disposable_domains do
  task :load, %i[s3_url] => [:environment] do |_task, args|
    file = Identity::Hostdata.secrets_s3.read_file(args[:s3_url])
    names = file.split("\n")
    DisposableDomain.insert_all(names.map { |name| { name: } })
  end
end
# rake "disposable_domains:load['URL_HERE']"
# rubocop:enable Rails/SkipsModelValidations
