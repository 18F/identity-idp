namespace :login do
  desc 'copy loa column data to ial in '
  task copy_loa_to_ial: :environment do
    ServiceProviderRequests.each do |spr|
      spr.ial = (spr.loa == 3 ? 2 : 1)
      spr.save!
    end
  end
end
