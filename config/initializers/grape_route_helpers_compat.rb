# frozen_string_literal: true

module GogglesApi
  # Temporary compatibility shim for grape-route-helpers on Grape >= 3.1.
  module GrapeRouteHelpersAllRoutesCompat
    def all_routes
      routes = subclasses.flat_map do |subclass|
        if subclass.respond_to?(:compile!)
          subclass.compile!
          subclass.respond_to?(:routes) ? subclass.routes : []
        elsif subclass.respond_to?(:prepare_routes, true)
          subclass.send(:prepare_routes)
        else
          []
        end
      end

      routes.uniq { |route| route.options.merge(path: route.path) }
    end
  end
end

Rails.application.config.to_prepare do
  next unless defined?(GrapeRouteHelpers::AllRoutes)
  next if GrapeRouteHelpers::AllRoutes < GogglesApi::GrapeRouteHelpersAllRoutesCompat

  GrapeRouteHelpers::AllRoutes.prepend(GogglesApi::GrapeRouteHelpersAllRoutesCompat)
end
