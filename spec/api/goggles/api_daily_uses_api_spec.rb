# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::APIDailyUsesAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:api_daily_use) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)    { FactoryBot.create(:user) }
  let(:crud_grant)   { FactoryBot.create(:admin_grant, user: crud_user, entity: 'APIDailyUse') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::APIDailyUse).and be_valid
    expect(admin_user).to be_a(GogglesDb::User).and be_valid
    expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(admin_headers).to be_an(Hash).and have_key('Authorization')
    expect(crud_user).to be_a(GogglesDb::User).and be_valid
    expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(fixture_headers).to be_an(Hash).and have_key('Authorization')
  end

  describe 'GET /api/v3/api_daily_use/:id' do
    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { get(api_v3_api_daily_use_path(id: fixture_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having just CRUD grants,' do
        before { get(api_v3_api_daily_use_path(id: fixture_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { get(api_v3_api_daily_use_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_api_daily_use_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_api_daily_use_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_api_daily_use_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::APIDailyUse.exists?(0)).to be false
        get(api_v3_api_daily_use_path(id: 0), headers: admin_headers)
      end

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/api_daily_use/:id' do
    let(:expected_changes) do
      [
        { day: Time.zone.today - (rand * 20).to_i.days },
        { route: "FAKE route #{(rand * 100_000_000).to_i}" },
        { count: (rand * 100).to_i }
      ].sample
    end

    before do
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_api_daily_use_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having just CRUD grants,' do
        before { put(api_v3_api_daily_use_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_api_daily_use_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_api_daily_use_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_api_daily_use_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_api_daily_use_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::APIDailyUse.exists?(0)).to be false
        put(api_v3_api_daily_use_path(id: 0), params: expected_changes, headers: admin_headers)
      end

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/api_daily_use/:id' do
    let(:deletable_row) { FactoryBot.create(:api_daily_use) }

    before { expect(deletable_row).to be_a(GogglesDb::APIDailyUse).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_api_daily_use_path(id: deletable_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_api_daily_use_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_api_daily_use_path(id: deletable_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_api_daily_use_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_api_daily_use_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_api_daily_use_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before do
        expect(GogglesDb::APIDailyUse.exists?(0)).to be false
        delete(api_v3_api_daily_use_path(id: 0), headers: admin_headers)
      end

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/api_daily_uses/' do
    let(:fixture_date) { (rand * 10).to_i.years.ago + (rand * 365).to_i.days }
    let(:fixture_route) { "FAKE route #{(rand * 100_000_000).to_i}" }
    let(:expected_row_count) { GogglesDb::APIDailyUse.where(route: fixture_route).count }
    let(:default_per_page) { 25 }
    # Make sure the Domain contains the expected seeds:

    before do
      FactoryBot.create_list(:api_daily_use, 26, day: fixture_date) # rubocop:disable FactoryBot/ExcessiveCreateList
      (1..6).each { |num| FactoryBot.create(:api_daily_use, route: fixture_route, day: Time.zone.today + num.days) }
      expect(GogglesDb::APIDailyUse.count).to be >= 32
      expect(expected_row_count).to be_positive
    end

    context 'without any filters,' do
      context 'with an account having ADMIN grants,' do
        before { get(api_v3_api_daily_uses_path, headers: admin_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account having just CRUD grants,' do
        before { get(api_v3_api_daily_uses_path, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { get(api_v3_api_daily_uses_path, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'without any filters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_api_daily_uses_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_api_daily_uses_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when filtering by a specific route,' do
      before { get(api_v3_api_daily_uses_path, params: { route: fixture_route }, headers: admin_headers) }

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by a specific day,' do
      before { get(api_v3_api_daily_uses_path, params: { day: fixture_date }, headers: admin_headers) }

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_api_daily_uses_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_api_daily_uses_path, params: { route: 'NON-EXISTING' }, headers: admin_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/api_daily_uses/summary' do
    let(:summary_user_agent) { 'Test-Agent/1.0' }
    let(:summary_headers) { admin_headers.merge('HTTP_USER_AGENT' => summary_user_agent) }

    before do
      FactoryBot.create(:api_daily_use, route: 'GET /api/v3/fake/route', count: 100)
      FactoryBot.create(:api_daily_use, route: 'REQ-10.0.0.1', count: 1000)
      FactoryBot.create(:api_daily_use_agent, user_agent: 'Bot/1.0', count: 50)
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { get(api_v3_api_daily_uses_summary_path, headers: summary_headers) }

        it 'is successful' do
          expect(response).to be_successful
        end

        it 'returns a JSON summary with the expected keys' do
          result = JSON.parse(response.body)
          expect(result.keys).to match_array(%w[top_routes top_ips top_agents totals])
          expect(result['totals'].keys).to match_array(%w[requests ip_requests route_requests])
          expect(result['top_routes']).to be_an(Array)
          expect(result['top_ips']).to be_an(Array)
          expect(result['top_agents']).to be_an(Array)
        end

        it 'returns top routes excluding REQ- routes' do
          result = JSON.parse(response.body)
          expect(result['top_routes']).not_to be_empty
          expect(result['top_routes'].pluck('route')).to all(match(/\A(?!REQ-)/i))
        end

        it 'returns top IPs stripped of the REQ- prefix' do
          result = JSON.parse(response.body)
          expect(result['top_ips']).not_to be_empty
          expect(result['top_ips'].first['ip']).to eq('10.0.0.1')
          expect(result['top_ips'].first['total_count']).to eq(1000)
        end

        it 'tracks the user agent' do
          expect(GogglesDb::APIDailyUseAgent.where(user_agent: summary_user_agent, day: Time.zone.today).count).to be_positive
        end
      end

      context 'with an account having just CRUD grants,' do
        before { get(api_v3_api_daily_uses_summary_path, headers: crud_headers.merge('HTTP_USER_AGENT' => summary_user_agent)) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { get(api_v3_api_daily_uses_summary_path, headers: fixture_headers.merge('HTTP_USER_AGENT' => summary_user_agent)) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_api_daily_uses_summary_path, headers: { 'Authorization' => 'you wish!', 'HTTP_USER_AGENT' => summary_user_agent }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/api_v3_api_daily_uses' do
    let(:min_row_count) { 5 }
    let(:fixture_day) { Time.zone.today - 1.month }
    let(:deletable_rows) { FactoryBot.create_list(:api_daily_use, min_row_count, day: fixture_day - 1.day, count: (rand * 20).to_i) }

    before { expect(deletable_rows).to all be_a(GogglesDb::APIDailyUse).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before do
          delete(api_v3_api_daily_uses_path, params: { day: fixture_day }, headers: admin_headers)
        end

        it_behaves_like('a successful request that has positive usage stats')
        it 'returns the number of deleted rows' do
          row_count = response.body.to_i
          # There may be a limited number of pre-existing seeds for this one, so we can't be sure of the exact number:
          expect(row_count).to be >= min_row_count
        end

        it 'deletes all rows older than the specified date' do
          expect(GogglesDb::APIDailyUse.exists?(['day < ?', fixture_day])).to be false
        end
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_api_daily_uses_path, params: { day: fixture_day }, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_api_daily_uses_path, params: { day: fixture_day }, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_api_daily_uses_path, params: { day: fixture_day }, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful request that has positive usage stats')
        it 'returns the number of deleted rows' do
          row_count = response.body.to_i
          expect(row_count).to be >= min_row_count
        end

        it 'deletes all rows older than the specified date' do
          expect(GogglesDb::APIDailyUse.exists?(['day < ?', fixture_day])).to be false
        end
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_api_daily_uses_path, params: { day: fixture_day }, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_api_daily_uses_path, params: { day: fixture_day }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting an invalid date,' do
      before { delete(api_v3_api_daily_uses_path, params: { day: 0 }, headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'returns the error response in the body' do
        msg = JSON.parse(response.body)
        expect(msg).to have_key('error')
        expect(msg['error']).to eq('day is invalid')
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
