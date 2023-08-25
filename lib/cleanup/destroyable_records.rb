class DestroyableRecords
  attr_reader :service_provider, :integration, :issuer, :stdin, :stdout

  def initialize(issuer, stdin: STDIN, stdout: STDOUT)
    @stdin = stdin
    @stdout = stdout

    @issuer = issuer
    @service_provider = ServiceProvider.includes(:in_person_enrollments).find_by(issuer: issuer)
    @integration = Agreements::Integration.includes(
      :partner_account,
      iaa_orders: [:iaa_gtc],
    ).find_by(issuer: issuer)
  end

  def print_data
    stdout.puts "You are about to delete a service provider with issuer #{service_provider.issuer}"
    stdout.puts "The partner is #{integration.partner_account.name}"
    stdout.puts "\n\n"

    stdout.puts 'Attributes:'
    stdout.puts service_provider.as_json.to_yaml
    stdout.puts "\n"

    stdout.puts '********'
    stdout.puts 'Integration:'
    stdout.puts integration.attributes.to_yaml
    stdout.puts "\n"

    stdout.puts '********'
    if in_person_enrollments.size == 0
      stdout.puts "This provider has #{in_person_enrollments.size} in person enrollments " \
                   "that will be destroyed"
    else
      stdout.puts "\e[31mThis provider has #{in_person_enrollments.size} in person enrollments " \
                   "that will be destroyed - Please handle these removals manually. " \
                   "For more details check https://cm-jira.usa.gov/browse/LG-10679\e[0m"
    end
    stdout.puts "\n"

    stdout.puts '*******'
    stdout.puts 'These are the IAA orders that will be affected: \n'
    iaa_orders.each do |iaa_order|
      stdout.puts "#{iaa_order.iaa_gtc.gtc_number} Order #{iaa_order.order_number}"
    end
    stdout.puts "\n"
  end

  def destroy_records
    stdout.puts 'Destroying integration usages'
    integration_usages.each do |integration_usage|
      integration_usage.destroy!
    end
    integration.reload

    stdout.puts "Destroying integration with issuer #{integration.issuer}"
    integration.destroy!
    service_provider.reload

    stdout.puts "Destroying service provider issuer #{service_provider.issuer}"
    service_provider.destroy!

    stdout.puts do
      "ServiceProvider with issuer #{issuer} and associated records has been destroyed."
    end
  end

  private

  def integration_usages
    integration.integration_usages
  end

  def iaa_orders
    integration.iaa_orders
  end

  def in_person_enrollments
    service_provider.in_person_enrollments
  end
end
