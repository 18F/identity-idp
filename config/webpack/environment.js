const { environment } = require('@rails/webpacker')
const allConfig = require('./all')
const erb =  require('./loaders/erb')

environment.config.merge(allConfig)
environment.config.merge({ devtool: 'none' })
environment.config.delete('output.chunkFilename')
environment.loaders.append('erb', erb)

module.exports = environment
