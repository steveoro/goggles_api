# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CmdAuthenticateUser, type: :command do
  let(:fixture_user) do
    user = FactoryBot.create(:user)
    expect(user).to be_a(GogglesDb::User).and be_valid
    user
  end

  context 'when using valid parameters,' do
    let(:fixture_email) { fixture_user.email }
    let(:fixture_pwd)   { fixture_user.password }

    describe '#call' do
      subject { described_class.new(fixture_email, fixture_pwd).call }

      let(:result_jwt) { subject.result }

      it 'returns itself' do
        expect(subject).to be_a(described_class)
      end

      it 'is successful' do
        expect(subject).to be_successful
      end

      it 'has a blank #errors list' do
        expect(subject.errors).to be_blank
      end

      it 'has a valid JWT string #result' do
        expect(result_jwt).to be_a(String).and be_present
        # Back-to-back test with JWT decoding:
        decoded_jwt = GogglesDb::JWTManager.decode(result_jwt, Rails.application.credentials.api_static_key)
        expect(decoded_jwt).to have_key('user_id')
        expect(decoded_jwt['user_id']).to eq(fixture_user.id)
      end
    end
  end
  #-- --------------------------------------------------------------------------
  #++

  %i[email password].each do |wrong_param|
    context "when using invalid parameters (wrong #{wrong_param})," do
      let(:fixture_email) { wrong_param == :email ? FactoryBot.build(:user).email : fixture_user.email }
      let(:fixture_pwd)   { wrong_param == :password ? '' : fixture_user.password }

      describe '#call' do
        subject { described_class.new(fixture_email, fixture_pwd).call }

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
          expect(subject.result).to be_nil
        end
      end
    end
  end
end
