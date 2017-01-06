namespace :rotate do

  # benchmark: 100k updates in 00:28:35 with cost '800$8$1$'
  # e.g.
  #  bundle exec rake rotate:email_encryption_key ATTRIBUTE_COST='800$8$1$'
  #
  desc 'attribute encryption key'
  task attribute_encryption_key: :environment do
    rotator = KeyRotator::AttributeEncryption.new
    num_users = User.count
    progress = new_progress_bar('Users', num_users)

    User.find_in_batches.with_index do |users, batch|
      User.transaction do
        users.each do |user|
          rotator.rotate(user)
          progress.increment
        end
      end
    end

    progress.finish
  end

  def new_progress_bar(label, num)
    ProgressBar.create(
      title: label,
      total: num,
      format: '%t: |%B| %j%% [%a / %e]'
    )
  end
end
