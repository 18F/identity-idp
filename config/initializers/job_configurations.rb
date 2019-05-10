# rubocop:disable Metrics/LineLength
JobRunner::Runner.configurations << JobRunner::JobConfiguration.new(
  name: 'Send GPO letter',
  interval: 300,
  timeout: 30,
  callback: -> { UspsConfirmationUploader.new.run unless HolidayService.observed_holiday?(Time.zone.today) },
)
# rubocop:enable Metrics/LineLength
