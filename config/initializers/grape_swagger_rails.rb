# frozen_string_literal: true

require 'grape-swagger/entity'

GrapeSwaggerRails.options.url = '/api/v3/swagger_doc'
GrapeSwaggerRails.options.app_name = 'Goggles API'
GrapeSwaggerRails.options.app_url = ''
GrapeSwaggerRails.options.doc_expansion = 'list'
GrapeSwaggerRails.options.api_auth = 'bearer'
GrapeSwaggerRails.options.api_key_name = 'Authorization'
GrapeSwaggerRails.options.api_key_type = 'header'
