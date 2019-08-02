const { environment } = require('@rails/webpacker')
const customConfig = require('./custom')
const erb =  require('./loaders/erb')

environment.config.merge(customConfig)
environment.config.merge({ devtool: 'none' })
environment.config.delete('output.chunkFilename')
environment.loaders.append('erb', erb)

module.exports = environment
