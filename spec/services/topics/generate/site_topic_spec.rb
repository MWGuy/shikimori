# frozen_string_literal: true

describe Topics::Generate::SiteTopic do
  subject { service.call }

  let(:locale) { 'ru' }
  let(:service) { Topics::Generate::SiteTopic.new model, user, locale }
  let(:user) { BotsService.get_poster }

  shared_examples_for :topic do
    context 'without existing topic' do
      it do
        expect { subject }.to change(Entry, :count).by 1
        is_expected.to have_attributes(
          forum_id: Topic::FORUM_IDS[model.class.name],
          generated: true,
          linked: model,
          user: user,
          locale: locale
        )

        expect(subject.created_at.to_i).to eq model.created_at.to_i
        expect(subject.updated_at).to be_nil
      end
    end

    context 'with existing topic' do
      let!(:topic) do
        create :"#{model.class.name.underscore}_topic",
          linked: model,
          locale: topic_locale
      end

      context 'for the same locale' do
        let(:topic_locale) { 'ru' }
        it 'does not generate new topic' do
          expect { subject }.not_to change(Entry, :count)
          is_expected.to eq topic
        end
      end

      context 'for different locale' do
        let(:topic_locale) { 'en' }
        it 'generates topic for new locale' do
          expect { subject }.to change(Entry, :count).by 1
          is_expected.not_to eq topic
        end
      end
    end
  end

  context 'anime' do
    let(:model) { create :anime }
    it_behaves_like :topic
  end

  context 'manga' do
    let(:model) { create :manga }
    it_behaves_like :topic
  end

  context 'character' do
    let(:model) { create :character }
    it_behaves_like :topic
  end

  context 'person' do
    let(:model) { create :person }
    it_behaves_like :topic
  end
end
