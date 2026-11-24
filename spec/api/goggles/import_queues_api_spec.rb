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

  # Creates a batch SQL row (with an attached SQL file storing +sql+) for the specified +user+.
  def create_batch_row(user, sql = "SELECT 1;\n", **attributes)
    row = FactoryBot.create(:import_queue, user:, batch_sql: true, **attributes)
    row.data_file.attach(io: StringIO.new(sql), filename: "0477-batch-#{row.id}.sql", content_type: 'application/sql')
    row.reload
  end

  describe 'GET /api/v3/import_queue/:id' do
    context 'when requesting a batch SQL row with ADMIN grants,' do
      let(:sql_contents) { "INSERT INTO laps (id) VALUES (1);\n" }
      let(:batch_row) do
        create_batch_row(admin_user, sql_contents, process_runs: 1, error_messages: 'ERROR 1062 (23000) at line 1: Duplicate entry')
      end
      let(:result) { JSON.parse(response.body) }

      before { get(api_v3_import_queue_path(id: batch_row.id), headers: admin_headers) }

      it_behaves_like('a successful request that has positive usage stats')

      it 'includes the data file name, checksum (base64 MD5) and byte size' do
        expect(result['data_file_name']).to eq("0477-batch-#{batch_row.id}.sql")
        expect(result['data_file_checksum']).to eq(Digest::MD5.base64digest(sql_contents))
        expect(result['data_file_byte_size']).to eq(sql_contents.bytesize)
      end

      it 'includes the outcome fields' do
        expect(result).to include(
          'id' => batch_row.id, 'batch_sql' => true, 'done' => false, 'process_runs' => 1,
          'error_messages' => 'ERROR 1062 (23000) at line 1: Duplicate entry'
        )
        expect(result).to have_key('created_at').and have_key('updated_at')
      end
    end

    context 'when requesting a micro-transaction row,' do
      before { get(api_v3_import_queue_path(id: fixture_row.id), headers: admin_headers) }

      it 'does not include any data file field' do
        expect(JSON.parse(response.body).keys).not_to include('data_file_name', 'data_file_checksum', 'data_file_byte_size')
      end
    end

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
      before do
        expect(GogglesDb::ImportQueue.exists?(0)).to be false
        get(api_v3_import_queue_path(id: 0), headers: admin_headers)
      end

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
        { uid: FFaker::UUID.uuidv4 }
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
      before do
        expect(GogglesDb::ImportQueue.exists?(0)).to be false
        put(api_v3_import_queue_path(id: 0), params: expected_changes, headers: admin_headers)
      end

      it_behaves_like 'an empty but successful JSON response'
    end

    context 'when retrying in place a failed batch SQL row (error_messages: "", process_runs: 0),' do
      let(:failed_row) { create_batch_row(admin_user, process_runs: 1, error_messages: 'ERROR 1064 (42000) at line 3') }

      before { put(api_v3_import_queue_path(id: failed_row.id), params: { error_messages: '', process_runs: 0 }, headers: admin_headers) }

      it_behaves_like('a successful request that has positive usage stats')

      it 'clears the error_messages (stored as nil) and resets the process_runs' do
        expect(response.body).to eq('true')
        expect(failed_row.reload).to have_attributes(error_messages: nil, process_runs: 0, done: false)
      end
    end

    context 'when setting the error_messages,' do
      before { put(api_v3_import_queue_path(id: fixture_row.id), params: { error_messages: 'interrupted: outcome unknown' }, headers: admin_headers) }

      it 'stores them' do
        expect(response.body).to eq('true')
        expect(fixture_row.reload.error_messages).to eq('interrupted: outcome unknown')
      end
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
        expect(GogglesDb::User.exists?(0)).to be false
        post(
          api_v3_import_queue_path,
          params: {
            user_id: 0,
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
      before do
        expect(GogglesDb::ImportQueue.exists?(0)).to be false
        delete(api_v3_import_queue_path(id: 0), headers: admin_headers)
      end

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/import_queues/' do
    let(:fixture_user_id) { GogglesDb::User.first(100).sample.id }
    let(:fixture_uid) { FFaker::UUID.uuidv4 }
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
      before do
        expect(GogglesDb::User.exists?(0)).to be false
        get(api_v3_import_queues_path, params: { user_id: 0 }, headers: admin_headers)
      end

      it_behaves_like('an empty but successful JSON list response')
    end
  end

  describe 'GET /api/v3/import_queues/ (Boolean filters & batch SQL rows)' do
    # Rows owned by a dedicated user, so that the shared test DB contents don't matter:
    let(:owner) { FactoryBot.create(:user) }
    let!(:micro_row) { FactoryBot.create(:import_queue, user: owner) }
    let!(:done_micro_row) { FactoryBot.create(:import_queue, user: owner, done: true) }
    let!(:queued_batch_row) { create_batch_row(owner) }
    let!(:applied_batch_row) { create_batch_row(owner, done: true, process_runs: 1) }
    let(:result_ids) { JSON.parse(response.body).pluck('id') }

    def list_for_owner(filters)
      get(api_v3_import_queues_path, params: filters.merge(user_id: owner.id), headers: admin_headers)
    end

    context 'when filtering by done=false,' do
      before { list_for_owner(done: false) }

      it_behaves_like('a successful request that has positive usage stats')

      it 'returns only the rows not done, sorted by ID, with the Total header' do
        expect(result_ids).to eq([micro_row.id, queued_batch_row.id])
        expect(response.headers['Total'].to_i).to eq(2)
      end
    end

    context 'when filtering by done=true,' do
      before { list_for_owner(done: true) }

      it 'returns only the rows done' do
        expect(result_ids).to eq([done_micro_row.id, applied_batch_row.id])
      end
    end

    context 'when filtering by batch_sql=true,' do
      before { list_for_owner(batch_sql: true) }

      it 'returns only the batch SQL rows, including the data file fields' do
        expect(result_ids).to eq([queued_batch_row.id, applied_batch_row.id])
        expect(JSON.parse(response.body)).to all(include('data_file_name', 'data_file_checksum', 'data_file_byte_size'))
        expect(JSON.parse(response.body).first['data_file_checksum']).to eq(queued_batch_row.data_file.blob.checksum)
      end
    end

    context 'when filtering by batch_sql=false,' do
      before { list_for_owner(batch_sql: false) }

      it 'returns only the micro-transaction rows' do
        expect(result_ids).to eq([micro_row.id, done_micro_row.id])
      end
    end

    context 'when filtering by batch_sql=true & done=false,' do
      before { list_for_owner(batch_sql: true, done: false) }

      it 'returns only the unfinished batch SQL rows' do
        expect(result_ids).to eq([queued_batch_row.id])
        expect(response.headers['Total'].to_i).to eq(1)
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
