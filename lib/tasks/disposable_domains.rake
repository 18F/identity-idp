namespace :disposable_domains do
  task :load, %i[s3_url] => [:environment] do |_task, args|
    file = Identity::Hostdata.secrets_s3.read_file(args[:s3_url])
    DisposableDomain.insert_all(file)
  end
end
# rake "disposable_domains:load"
