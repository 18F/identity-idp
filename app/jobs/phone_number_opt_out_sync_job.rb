class PhoneNumberOptOutSyncJob < ApplicationJob
  queue_as :long_running
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> do
      rounded = TimeService.round_time(time: arguments.first, interval: 1.hour)
      "phone-number-opt-out-sync-#{rounded.to_i}"
    end,
  )

  def perform(_now)
    all_phone_numbers = Set.new

    opt_out_manager.opted_out_numbers.each do |phone_number|
      PhoneNumberOptOut.mark_opted_out(phone_number)
      all_phone_numbers << phone_number
    end

    Rails.logger.info(
      {
        name: 'opt_out_sync_job',
        opted_out_count: all_phone_numbers.count,
      }.to_json,
    )
  end

  def opt_out_manager
    Telephony::Pinpoint::OptOutManager.new
  end
end
