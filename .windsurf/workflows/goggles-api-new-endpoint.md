---
description: Add a new Grape API endpoint to goggles_api — controller, params, specs, and API Blueprint docs
auto_execution_mode: 2
---

# New API Endpoint

Use this skill when adding a new Grape API endpoint to `goggles_api`. The API uses the Grape framework with JWT authentication, Kaminari pagination, and a consistent pattern across 38 existing endpoint files.

## Prerequisites

- The model must already exist in `goggles_db` (see `/goggles-data-model` skill)
- Ensure `goggles_api` has the latest engine (`./update_engine.sh`)

## File Locations

All paths relative to `/home/steve/Projects/goggles_api/`:

- **Endpoint files**: `app/api/goggles/<model_name>s_api.rb`
- **Master mount**: `app/api/goggles/api.rb`
- **Shared helpers**: `app/api/goggles/api_helpers.rb`
- **Request specs**: `spec/api/goggles/<model_name>s_api_spec.rb`
- **API Blueprint docs**: `blueprint/`

## Step-by-step Procedure

### 1. Create the Endpoint File

Create `app/api/goggles/<model_name>s_api.rb`. Follow the established pattern from `swimmers_api.rb`:

```ruby
# frozen_string_literal: true

module Goggles
  # = Goggles API v3: <ModelName> API Grape controller
  #
  #   - version:  7-0.x.xx
  #   - author:   Steve A.
  #   - build:    YYYYMMDD
  #
  class <ModelName>sAPI < Grape::API
    helpers APIHelpers

    format       :json
    content_type :json, 'application/json'

    # === Singular resource (detail + update + create) ===
    resource :<model_name> do
      # GET /api/:version/<model_name>/:id
      desc '<ModelName> details'
      params do
        requires :id, type: Integer, desc: '<ModelName> ID'
        optional :locale, type: String, desc: 'optional: Locale override (default \'it\')'
      end
      route_param :id do
        get do
          check_jwt_session
          I18n.locale = params['locale'] if params['locale'].present?
          GogglesDb::<ModelName>.find_by(id: params['id'])
        end
      end

      # PUT /api/:version/<model_name>/:id
      desc 'Update <ModelName> details'
      params do
        requires :id, type: Integer, desc: '<ModelName> ID'
        # optional params for updatable fields...
      end
      route_param :id do
        put do
          api_user = check_jwt_session
          reject_unless_authorized_for_crud(api_user, '<ModelName>')
          row = GogglesDb::<ModelName>.find_by(id: params['id'])
          row&.update!(declared(params, include_missing: false))
        end
      end

      # POST /api/:version/<model_name>
      desc 'Create a new <ModelName>'
      params do
        # requires/optional params for creation...
      end
      post do
        api_user = check_jwt_session
        reject_unless_authorized_admin(api_user)
        new_row = GogglesDb::<ModelName>.create(params)
        unless new_row.valid?
          error!(
            I18n.t('api.message.creation_failure'),
            422,
            'X-Error-Detail' => GogglesDb::ValidationErrorTools.recursive_error_for(new_row)
          )
        end
        { msg: I18n.t('api.message.generic_ok'), new: new_row }
      end
    end

    # === Plural resource (list/search) ===
    resource :<model_name>s do
      # GET /api/:version/<model_name>s
      desc 'List <ModelName>s'
      params do
        # optional filtering params...
        optional :select2_format, type: Boolean, desc: 'optional: enable Select2 output format'
        use :pagination
      end
      paginate
      get do
        check_jwt_session
        results = filtering_fulltext_search_for(GogglesDb::<ModelName>, params['name'])
                  .where(filtering_hash_for(params, %w[<exact_match_columns>]))
                  .where(filtering_like_for(params, %w[<partial_match_columns>]))
        if params['select2_format'] == true
          select2_custom_format(results, ->(row) { row.display_label })
        else
          paginate(results).map(&:to_hash)
        end
      end
    end
  end
end
```

### 2. Mount the Endpoint

Edit `app/api/goggles/api.rb` and add a `mount` line in alphabetical order:

```ruby
mount <ModelName>sAPI
```

### 3. Key Helper Methods (from `api_helpers.rb`)

- **`check_jwt_session`** — validates JWT, returns the API user
- **`reject_unless_authorized_for_crud(user, entity_name)`** — checks `AdminGrant` for CRUD permission
- **`reject_unless_authorized_admin(user)`** — checks full admin permission
- **`filtering_hash_for(params, columns)`** — builds exact-match WHERE clause
- **`filtering_like_for(params, columns)`** — builds LIKE WHERE clause
- **`filtering_fulltext_search_for(model, term)`** — FULLTEXT search if model supports it
- **`append_fuzzy_search_results_for(model, fields, results)`** — appends fuzzy matches
- **`select2_custom_format(results, label_lambda)`** — formats for Select2 dropdown
- **`use :pagination`** — includes Kaminari pagination params (`page`, `per_page`)

### 4. Write Request Specs

Create `spec/api/goggles/<model_name>s_api_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goggles::<ModelName>sAPI do
  # ... setup JWT, factory instances, etc.

  describe 'GET /api/v3/<model_name>/:id' do
    # test happy path, not found, unauthorized
  end

  describe 'PUT /api/v3/<model_name>/:id' do
    # test update with valid params, unauthorized, invalid params
  end

  describe 'POST /api/v3/<model_name>' do
    # test creation, validation errors, unauthorized
  end

  describe 'GET /api/v3/<model_name>s' do
    # test list with filters, pagination, select2_format
  end
end
```

### 5. Run Tests

```bash
cd /home/steve/Projects/goggles_api
bundle exec rspec spec/api/goggles/<model_name>s_api_spec.rb
```

### 6. Update API Blueprint (Optional)

Add endpoint documentation in `blueprint/` following the existing `.apib` format.

## Authorization Patterns

- **Read (GET)**: `check_jwt_session` — any authenticated user
- **Update (PUT)**: `reject_unless_authorized_for_crud(user, 'EntityName')` — needs `AdminGrant` for entity
- **Create (POST)**: `reject_unless_authorized_admin(user)` — admin only
- **Delete (DELETE)**: `reject_unless_authorized_admin(user)` — admin only (used sparingly)

## Pagination

The API uses `api-pagination` + `kaminari`. Response headers include:

- `Link` — next/last page URLs
- `Total` — total row count
- `Per-Page` — rows per page
- `Page` — current page number
