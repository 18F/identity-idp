# frozen_string_literal: true

namespace :rotate do
  # benchmark: 100k updates in 00:28:35 with cost '800$8$1$'
  # e.g.
  #  bundle exec rake rotate:email_encryption_key
  #
  desc 'attribute encryption key'
  task attribute_encryption_key: :environment do
    num_users = User.count
    num_phone_opt_outs = PhoneNumberOptOut.count
    progress = new_progress_bar('Users', num_users)
    progress_phone_number_opt_outs = new_progress_bar('PhoneNumberOptOuts', num_phone_opt_outs)

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

          user.auth_app_configurations.each do |auth_app_configuration|
            rotator = KeyRotator::AttributeEncryption.new(auth_app_configuration)
            rotator.rotate
          end
          progress&.increment
        rescue StandardError => err # Don't use user.email in output...
          Kernel.puts "Error with user id:#{user.id} #{err.message} #{err.backtrace}"
        end
      end
    end

    PhoneNumberOptOut.find_in_batches.with_index do |phone_number_opt_outs, _batch|
      PhoneNumberOptOut.transaction do
        phone_number_opt_outs.each do |phone_number_opt_out|
          rotator = KeyRotator::AttributeEncryption.new(phone_number_opt_out)
          rotator.rotate
        end
        progress_phone_number_opt_outs&.increment
      rescue StandardError => err # Don't use user.email in output...
        Kernel.puts "Error with user id:#{user.id} #{err.message} #{err.backtrace}"
      end
    end
  end

  desc 'hmac fingerprinter key'
  task hmac_fingerprinter_key: :environment do
    num_users = User.count
    progress = new_progress_bar('Users', num_users)

    User.find_in_batches.with_index do |users, _batch|
      User.transaction do
        users.each do |user|
          KeyRotator::HmacFingerprinter.new.rotate(user: user)
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
