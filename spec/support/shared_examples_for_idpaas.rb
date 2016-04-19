shared_examples 'connecting to IdPaas with Net::HTTP' do
  it 'parses a URI when initialized' do
    expect(request.instance_variable_get(:@uri).to_s).to eq(url)
  end

  it 'sets the open_timeout option to 30 seconds' do
    expect(Net::HTTP).to receive(:start).
      with(uri.host, uri.port, use_ssl: false, open_timeout: 30)

    request.response
  end

  it 'sets the use_ssl option to use_ssl?' do
    expect(Net::HTTP).to receive(:start).
      with(uri.host, uri.port, use_ssl: request.use_ssl?, open_timeout: 30)

    request.response
  end

  it 'sets use_ssl? to true' do
    expect(request.use_ssl?).to eq true
  end
end
