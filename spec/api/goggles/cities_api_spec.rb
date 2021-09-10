# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::CitiesAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { GogglesDb::City.first(30).sample }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }
  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'City') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::City).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(crud_user).to be_a(GogglesDb::User).and be_valid
    expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(crud_headers).to be_an(Hash).and have_key('Authorization')
  end

  describe 'GET /api/v3/city/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_city_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_city_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_city_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get api_v3_city_path(id: -1), headers: fixture_headers }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/city/:id' do
    let(:fixture_row) { FactoryBot.create(:city) }
    let(:new_values) do
      FactoryBot.build(
        :city,
        area: FFaker::Address.neighborhood,
        zip: FFaker::AddressCHIT.postal_code,
        latitude: FFaker::Geolocation.lat,
        longitude: FFaker::Geolocation.lng
      )
    end
    let(:expected_changes) do
      [
        { name: new_values.name },
        { country_code: new_values.country_code },
        { country: new_values.country },
        { area: new_values.area },
        { zip: new_values.zip },
        { latitude: new_values.latitude, longitude: new_values.longitude }
      ].sample
    end

    before do
      expect(fixture_row).to be_a(GogglesDb::City).and be_valid
      expect(new_values).to be_a(GogglesDb::City).and be_valid
      expect(expected_changes).to be_a(Hash)
    end

    context 'when using valid parameters,' do
      context 'with an account having CRUD grants,' do
        before { put(api_v3_city_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_city_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_city_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_city_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_city_path(id: -1), params: expected_changes, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/city' do
    let(:built_row)  { FactoryBot.build(:city, zip: FFaker::AddressCHIT.postal_code, latitude: FFaker::Geolocation.lat, longitude: FFaker::Geolocation.lng) }
    let(:admin_user) { FactoryBot.create(:user) }
    let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
    let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }

    before do
      expect(built_row).to be_a(GogglesDb::City).and be_valid
      expect(admin_user).to be_a(GogglesDb::User).and be_valid
      expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(admin_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_city_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_city_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_city_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_city_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when using missing or invalid parameters,' do
      before { post(api_v3_city_path, params: { name: [nil, ''].sample, country: [nil, ''].sample, country_code: [nil, ''].sample }, headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.creation_failure'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to be_present
      end
    end
  end
  # -- -------------------------------------------------------------------------
  # ++

  describe 'GET /api/v3/cities' do
    context 'when using a valid authentication' do
      let(:default_per_page) { 25 }

      context 'without any filters,' do
        before { get(api_v3_cities_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when using valid parameters but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_cities_path, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific country,' do
        before { get(api_v3_cities_path, params: { country: 'Italy' }, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'when filtering by a specific country_code,' do
        before { get(api_v3_cities_path, params: { country_code: 'IT' }, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      # Checking specific accented or partial names:
      %w[FORLI Cesena L'aquila LAquila reggio].each do |fixture_name|
        context "filtering by a generic name (#{fixture_name})," do
          let(:expected_results) { GogglesDb::City.for_name(fixture_name) }
          let(:expected_row_count) { expected_results.count }

          before { get(api_v3_cities_path, params: { name: fixture_name }, headers: fixture_headers) }

          it_behaves_like('successful multiple row response either with OR without pagination links')
        end
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_cities_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_cities_path, params: { name: '?@12345!' }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  # -- -------------------------------------------------------------------------
  # ++

  describe 'GET /api/v3/cities/search' do
    context 'when using a valid authentication' do
      let(:default_per_page) { 25 }

      context 'without any filters,' do
        before { get(api_v3_cities_search_path, headers: fixture_headers) }

        it 'is NOT successful' do
          expect(response).not_to be_successful
        end

        it 'responds with a generic error message and its details in the header' do
          result = JSON.parse(response.body)
          expect(result).to have_key('error')
          expect(result['error']).to eq('name is missing, country_code is missing')
        end
      end

      # Checking specific accented or partial names:
      %w[
        FORLI forlì Cesena L'aquila LAquila reggio Parm modena riccione lodi reggioemilia
      ].each do |fixture_name|
        context "when searching for a specific peculiar name (#{fixture_name}) with multiple results," do
          let(:result_country) { GogglesDb::CmdFindIsoCountry.call(nil, 'IT').result }
          let(:result_city_finder) { GogglesDb::CmdFindIsoCity.call(result_country, fixture_name) }
          let(:expected_row_count) { result_city_finder.matches.count }

          before do
            expect(result_country).to be_an(ISO3166::Country)
            expect(result_city_finder).to be_successful
            get(
              api_v3_cities_search_path,
              params: { name: fixture_name, country_code: 'IT' },
              headers: fixture_headers
            )
          end

          it 'has the required field structure' do
            result_array = JSON.parse(response.body)
            expect(result_array.first.keys).to include('name', 'latitude', 'longitude', 'region_num', 'region')
          end

          it_behaves_like('successful multiple row response either with OR without pagination links')
        end
      end

      context 'and with valid parameters but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_cities_search_path, params: { name: 'reggio', country_code: 'IT' }, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_cities_search_path, params: { name: 'Roma', country_code: 'IT' }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_cities_search_path, params: { name: '?@No-City!', country_code: 'IT' }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
end
