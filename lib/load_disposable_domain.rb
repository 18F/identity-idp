class LoadDisposableDomain
  def self.load_disposable_domains(url)
    Faraday.get(url).body.each_line do |line|
      DisposableDomain.find_or_create_by(name: line)
    end
  end
end
