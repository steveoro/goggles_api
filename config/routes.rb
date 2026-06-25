# frozen_string_literal: true

Rails.application.routes.draw do
  mount Goggles::API => '/'
  mount GrapeSwaggerRails::Engine => '/api/docs' if Rails.env.development?
end
