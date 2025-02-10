# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
require 'csv'
namespace :disposable_email_domains do
  task :load, %i[s3_secrets_path] => [:environment] do |_task, args|
    # Need to increase statement timeout since command takes a long time.
    ActiveRecord::Base.connection.execute 'SET statement_timeout = 200000'
    file = Identity::Hostdata.secrets_s3.read_file(args[:s3_secrets_path])
    names = file.split("\n")
    DisposableEmailDomain.insert_all(names.map { |name| { name: } })
  end
end
# rake "disposable_email_domains:load[S3_SECRETS_PATH]"
# rubocop:enable Rails/SkipsModelValidations
