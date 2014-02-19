require 'spec_helper'

describe Api::V1::UsersController do
  let(:user) { create :user }

  describe :show do
    before { get :show, id: user.id, format: :json }

    it { should respond_with :success }
    it { should respond_with_content_type :json }
  end

  describe :whoami do
    describe :signed_in do
      before { sign_in user }
      before { get :whoami, format: :json }

      it { should respond_with :success }

      context :json do
        subject { OpenStruct.new JSON.parse(response.body) }
        its(:id) { should eq user.id }
        its(:nickname) { should eq user.nickname }
      end
    end

    describe :guest do
      before { get :whoami, format: :json }
      specify { response.body.should eq 'null' }
    end unless ENV['APIPIE_RECORD']
  end

  describe :friends do
    let(:user) { create :user, friends: [create(:user)] }

    before { get :friends, id: user.id, format: :json }
    it { should respond_with :success }
  end

  describe :anime_rates do
    let(:user) { create :user }
    let(:anime) { create :anime }
    let!(:user_rate) { create :user_rate, target: anime, user: user }

    before { get :anime_rates, id: user.id, format: :json }
    it { should respond_with :success }
  end

  describe :manga_rates do
    let(:user) { create :user }
    let(:manga) { create :manga }
    let!(:user_rate) { create :user_rate, target: manga, user: user }

    before { get :manga_rates, id: user.id, format: :json }
    it { should respond_with :success }
  end

  describe :clubs do
    let(:user) { create :user, groups: [create(:group)] }

    before { get :clubs, id: user.id, format: :json }
    it { should respond_with :success }
  end

  describe :favourites do
    let(:user) do
      create :user,
        fav_animes: [create(:anime)],
        fav_mangas: [create(:manga)],
        fav_characters: [create(:character)],
        fav_persons: [create(:person)],
        fav_mangakas: [create(:person)],
        fav_producers: [create(:person)],
        fav_seyu: [create(:person)]
    end

    before { get :favourites, id: user.id, format: :json }
    it { should respond_with :success }
  end

  describe :messages do
    let(:user_2) { create :user }
    let(:topic) { create :anime_news, linked: create(:anime) }
    let!(:news) { create :message, kind: MessageType::Anons, to: user, from: user_2, body: 'anime [b]anons[/b]', linked: topic }

    context :signed_in do
      before { sign_in user }
      before { get :messages, id: user.id, page: 1, limit: 20, type: 'news', format: :json }
      it { should respond_with :success }
    end

    context :guest do
      before { get :messages, id: user.id, page: 1, limit: 20, type: 'news', format: :json }
      it { should respond_with 401 }
    end unless ENV['APIPIE_RECORD']
  end

  describe :unread_messages do
    context :signed_in do
      before { sign_in user }
      before { get :unread_messages, id: user.id, format: :json }
      it { should respond_with :success }
    end

    context :guest do
      before { get :unread_messages, id: user.id, format: :json }
      it { should respond_with 401 }
    end unless ENV['APIPIE_RECORD']
  end

  describe :history do
    let!(:entry_1) { create :user_history, user: user, action: 'mal_anime_import', value: '522' }
    let!(:entry_2) { create :user_history, target: create(:anime), user: user, action: 'status' }

    describe :index do
      before { get :history, id: user.id, limit: 10, page: 1, format: :json }
      it { should respond_with :success }
    end
  end
end
