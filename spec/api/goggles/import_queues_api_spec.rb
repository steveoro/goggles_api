# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::ImportQueuesAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:import_queue_existing_swimmer) }
  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'ImportQueue') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::ImportQueue).and be_valid
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

  describe 'GET /api/v3/import_queue/:id' do
    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { get(api_v3_import_queue_path(id: fixture_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having just CRUD grants,' do
        before { get(api_v3_import_queue_path(id: fixture_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { get(api_v3_import_queue_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_import_queue_path(id: fixture_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON row response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_import_queue_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_import_queue_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { get(api_v3_import_queue_path(id: -1), headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/import_queue/:id' do
    let(:expected_changes) do
      [
        { user_id: GogglesDb::User.first(100).sample.id },
        { request_data: { team: { name: "#{FFaker::Address.city} Swimming Club #{1990 + (30 * rand).to_i}" } }.to_json },
        { solved_data: { swimmer_id: GogglesDb::Swimmer.first(100).sample.id }.to_json },
        { process_runs: (rand * 10).to_i },
        { done: [true, false].sample },
        { uid: FFaker::Guid.guid }
      ].sample
    end

    before do
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { put(api_v3_import_queue_path(id: fixture_row.id), params: expected_changes, headers: admin_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having just CRUD grants,' do
        before { put(api_v3_import_queue_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { put(api_v3_import_queue_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_import_queue_path(id: fixture_row.id), params: expected_changes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON PUT response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_import_queue_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_import_queue_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_import_queue_path(id: -1), params: expected_changes, headers: admin_headers) }

      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/import_queue' do
    # Make sure parameters for the POST include all required attributes:
    let(:built_row) { FactoryBot.build(:import_queue_existing_team, user_id: GogglesDb::User.first(100).sample.id) }

    before do
      expect(built_row).to be_a(GogglesDb::ImportQueue).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_import_queue_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_import_queue_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_import_queue_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_import_queue_path, params: built_row.attributes, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_import_queue_path, params: built_row.attributes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_import_queue_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before do
        post(
          api_v3_import_queue_path,
          params: {
            user_id: -1,
            request_data: {}.to_json,
            uid: built_row.uid
          },
          headers: admin_headers
        )
      end

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
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/import_queue/batch_sql' do
    let(:fixture_path) { GogglesDb::Engine.root.join('spec', 'fixtures', 'test-script.sql') }
    let(:fixture_file) { Rack::Test::UploadedFile.new(GogglesDb::Engine.root.join('spec', 'fixtures', 'test-script.sql')) }

    before do
      expect(fixture_path).to be_present
      expect(File.exist?(fixture_path)).to be true
      expect(fixture_file).to be_present
    end

    # REQUIRES:
    # - fixture_path: path to the fixture file uploaded as multipart file
    # PARAMS:
    # - model_klass: the model class
    # - content_helper: helper method called on the model instance to retrieve the attached file contents
    shared_examples_for('a successful multipart POST request returning just the ID of the new row') do |model_klass, content_helper|
      it_behaves_like('a successful request that has positive usage stats')

      it 'returns an OK message and the new row ID as a JSON object' do
        result = JSON.parse(response.body)
        expect(result).to have_key('msg').and have_key('new')
        expect(result['msg']).to eq(I18n.t('api.message.generic_ok'))
        resulting_id = result['new']['id'].to_i
        expect(resulting_id).to be_positive
        expect(model_klass.exists?(id: resulting_id)).to be true
        stored_row = model_klass.find(resulting_id)
        expect(stored_row.send(content_helper)).to eq(File.read(fixture_path))
      end
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_import_queue_batch_sql_path, params: { data_file: fixture_file }, headers: admin_headers) }

        it_behaves_like(
          'a successful multipart POST request returning just the ID of the new row',
          GogglesDb::ImportQueue,
          :data_file_contents
        )
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_import_queue_batch_sql_path, params: { data_file: fixture_file }, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_import_queue_batch_sql_path, params: { data_file: fixture_file }, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_import_queue_batch_sql_path, params: { data_file: fixture_file }, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like(
          'a successful multipart POST request returning just the ID of the new row',
          GogglesDb::ImportQueue,
          :data_file_contents
        )
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          post(api_v3_import_queue_batch_sql_path, params: { data_file: fixture_file }, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_import_queue_batch_sql_path, params: { data_file: fixture_file }, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using missing or invalid parameters,' do
      before { post(api_v3_import_queue_batch_sql_path, params: { data_file: nil }, headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.invalid_parameter'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to be_present
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/import_queue/:id' do
    let(:deletable_row) { FactoryBot.create(:import_queue) }

    before { expect(deletable_row).to be_a(GogglesDb::ImportQueue).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_import_queue_path(id: deletable_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_import_queue_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_import_queue_path(id: deletable_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_import_queue_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_import_queue_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_import_queue_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_import_queue_path(id: -1), headers: admin_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/import_queues/' do
    let(:fixture_user_id) { GogglesDb::User.first(100).sample.id }
    let(:fixture_uid) { FFaker::Guid.guid }
    let(:expected_row_count) { GogglesDb::ImportQueue.where(uid: fixture_uid).count }
    let(:default_per_page) { 25 }
    # Make sure the Domain contains the expected seeds:

    before do
      FactoryBot.create_list(:import_queue_existing_team, 26, user_id: fixture_user_id) # rubocop:disable FactoryBot/ExcessiveCreateList
      FactoryBot.create_list(:import_queue_existing_swimmer, 5, uid: fixture_uid)
      expect(GogglesDb::ImportQueue.count).to be >= 31
      expect(expected_row_count).to be_positive
    end

    context 'without any filters,' do
      context 'with an account having ADMIN grants,' do
        before { get(api_v3_import_queues_path, headers: admin_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account having just CRUD grants,' do
        before { get(api_v3_import_queues_path, headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { get(api_v3_import_queues_path, headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'without any filters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_import_queues_path, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_import_queues_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when filtering by a specific UID,' do
      before { get(api_v3_import_queues_path, params: { uid: fixture_uid }, headers: admin_headers) }

      it_behaves_like('successful multiple row response either with OR without pagination links')
    end

    context 'when filtering by a specific User ID,' do
      before { get(api_v3_import_queues_path, params: { user_id: fixture_user_id }, headers: admin_headers) }

      it_behaves_like('successful response with pagination links & values in headers')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_import_queues_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_import_queues_path, params: { user_id: -1 }, headers: admin_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
