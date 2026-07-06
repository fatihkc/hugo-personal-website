const { defineConfig } = require('cypress')

module.exports = defineConfig({
  fixturesFolder: false,
  e2e: {
    // Production by default; override with CYPRESS_BASE_URL
    // (e.g. http://localhost:1313 to test a local hugo server).
    baseUrl: 'https://fatihkoc.net',
    setupNodeEvents(on, config) {},
    supportFile: false,
  },
})
