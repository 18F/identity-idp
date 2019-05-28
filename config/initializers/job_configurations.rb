# rubocop:disable Metrics/LineLength
JobRunner::Runner.configurations << JobRunner::JobConfiguration.new(
  name: 'Send GPO letter',
  interval: 24 * 60 * 60,
  timeout: 300,
  callback: -> { UspsConfirmationUploader.new.run unless HolidayService.observed_holiday?(Time.zone.today) },
)
# rubocop:enable Metrics/LineLength
