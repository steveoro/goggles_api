# frozen_string_literal: true

require 'grape-route-helpers'

# = GogglesApi::GrapeRouteHelpersAllRoutesCompat
#
# Compatibility shim for grape-route-helpers on Grape >= 3.1
#
module GogglesApi
  # Temporary compatibility shim
  module GrapeRouteHelpersAllRoutesCompat
    def all_routes
      api_classes = respond_to?(:descendants) ? descendants : subclasses
      routes = api_classes.flat_map do |subclass|
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

  def self.apply_grape_route_helpers_compat!
    return unless defined?(GrapeRouteHelpers::AllRoutes)
    return if GrapeRouteHelpers::AllRoutes < GrapeRouteHelpersAllRoutesCompat

    GrapeRouteHelpers::AllRoutes.prepend(GrapeRouteHelpersAllRoutesCompat)
  end
end

Rails.application.config.after_initialize do
  GogglesApi.apply_grape_route_helpers_compat!
end
