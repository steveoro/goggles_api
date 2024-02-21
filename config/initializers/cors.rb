# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

# rubocop:disable Style/RegexpLiteral
Rails.application.config.middleware.insert_before 0, Rack::Cors, debug: true, logger: -> { Rails.logger } do
  allow do
    # NOTE: origins '*' is now deemed as "too loose" and doesn't allow the "credentials: true" anymore
    origins(
      /http:\/\/0\.0\.0\.0(:\d+)?/,
      /http:\/\/127\.0\.0\.1(:\d+)?/,
      /localhost(:\d+)?/,
      /192\.168\.[01]\.\d{1,3}(:\d+)?/,
      /(www\.)?master-goggles.org(:\d+)?/,
      /ccdc9a45-abb2-4b8e-ac7f-e65da7c3aa04/ # Mozilla RESTClient extension installed on dev localhost
    )
    resource(
      '*',
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true, # (default false; JWT is already encrypted and we need to send it through)
      # [Optional] Specify how long the preflight request cache should last:
      max_age: 86_400
      # [Optional] Specify which response headers are exposed to the browser:
      # expose: %w[Access-Control-Allow-Private-Network]
      # List here headers to expose with their value:
      # 'Access-Control-Allow-Private-Network': true
    )
  end
end
# rubocop:enable Style/RegexpLiteral

# [Steve A.] Not needed right now: (Introduced to restrict the allowed hosts)
# Rails.application.config.hosts << /http:\/\/0\.0\.0\.0(:\d+)?/
# Rails.application.config.hosts << /http:\/\/127\.0\.0\.1(:\d+)?/
# Rails.application.config.hosts << /localhost(:\d+)?\z/
# Rails.application.config.hosts << /http:\/\/192\.168\.[01]\.\d{1,3}(:\d+)?\z/
# Rails.application.config.hosts << /(www\.)?master-goggles.org(:\d+)?/
