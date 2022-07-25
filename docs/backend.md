# Back-end archictecture

The IDP is a Rails application, that follows many typical Rails conventions.

## Networking

For consistency, we use [Faraday](https://github.com/lostisland/faraday)
when making HTTP requests. We also wire in notifications so we can
[log metrics on these requests](../config/initializers/faraday.rb)
