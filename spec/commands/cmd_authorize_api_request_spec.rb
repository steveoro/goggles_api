# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CmdAuthorizeAPIRequest, type: :command do
  let(:fixture_user) do
    user = FactoryBot.create(:user)
    expect(user).to be_a(GogglesDb::User).and be_valid
    user
  end

  context 'when using valid parameters,' do
    let(:fixture_jwt) do
      result = CmdAuthenticateUser.new(fixture_user.email, fixture_user.password).call.result
      expect(result).to be_a(String).and be_present
      result
    end
    let(:fixture_headers) { { 'Authorization' => "Bearer #{fixture_jwt}" } }

    describe '#call' do
      subject { described_class.new(fixture_headers).call }

      let(:result_user) { subject.result }

      it 'returns itself' do
        expect(subject).to be_a(described_class)
      end

      it 'is successful' do
        expect(subject).to be_successful
      end

      it 'has a blank #errors list' do
        expect(subject.errors).to be_blank
      end

      it 'has a valid User #result' do
        expect(result_user).to be_a(GogglesDb::User).and be_valid
        expect(result_user.id).to eq(fixture_user.id)
      end
    end
  end
  #-- --------------------------------------------------------------------------
  #++

  %i[header jwt].each do |wrong_param|
    context "when using invalid parameters (wrong #{wrong_param})," do
      describe '#call' do
        subject do
          headers = if wrong_param == :header
                      { 'Auth' => 'Not_a_valid_header!' }
                    else # wrong JWT / credentials
                      { 'Authorization' => 'Bearer Not_a_valid_JWT!' }
                    end
          described_class.new(headers).call
        end

        it 'returns itself' do
          expect(subject).to be_a(described_class)
        end

        it 'fails' do
          expect(subject).to be_a_failure
        end

        it 'has a non-empty #errors list' do
          expect(subject.errors).to be_present
        end

        it 'has a nil #result' do
          expect(subject.result).to be nil
        end
      end
    end
  end
end
