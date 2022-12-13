Geocoder.configure(ip_lookup: :test)

Geocoder::Lookup::Test.add_stub(
  '1.2.3.4',
  [
    {
      'city' => 'foo',
      'country' => 'United States',
      'state_code' => '',
    },
  ],
)

Geocoder::Lookup::Test.add_stub(
  '159.142.31.80',
  [
    {
      'city' => 'Arlington',
      'country' => 'United States',
      'state_code' => 'VA',
    },
  ],
)

Geocoder::Lookup::Test.add_stub(
  '4.3.2.1',
  [
    {
      'city' => '',
      'country' => '',
      'state_code' => '',
    },
  ],
)

Geocoder::Lookup::Test.add_stub(
  '127.0.0.1',
  [
    {
      'city' => '',
      'country' => 'United States',
      'state_code' => '',
    },
  ],
)
