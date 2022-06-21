namespace :rotate do
  # benchmark: 100k updates in 00:28:35 with cost '800$8$1$'
  # e.g.
  #  bundle exec rake rotate:email_encryption_key
  #
  desc 'attribute encryption key'
  task attribute_encryption_key: :environment do
    num_users = User.count
    progress = new_progress_bar('Users', num_users)

    User.find_in_batches.with_index do |users, _batch|
      User.transaction do
        users.each do |user|
          user.phone_configurations.each do |phone_configuration|
            rotator = KeyRotator::AttributeEncryption.new(phone_configuration)
            rotator.rotate
          end
          user.email_addresses.each do |email_address|
            rotator = KeyRotator::AttributeEncryption.new(email_address)
            rotator.rotate
          end
          progress&.increment
        rescue StandardError => err # Don't use user.email in output...
          Kernel.puts "Error with user id:#{user.id} #{err.message} #{err.backtrace}"
        end
      end
    end
  end

  def new_progress_bar(label, num)
    return if ENV['PROGRESS'] == 'no'
    ProgressBar.create(
      title: label,
      total: num,
      format: '%t: |%B| %j%% [%a / %e]',
    )
  end
end
