class TopicsController < ForumController
  include TopicsHelper

  before_filter :check_auth, only: [:new, :edit, :create, :update]
  before_filter :check_post_permission, only: [:create, :update]

  caches_action :index,
                :cache_path => proc { Digest::MD5.hexdigest "#{request.path}|#{params.to_json}|#{Comment.last.updated_at}|#{json?}" },
                :unless => proc { user_signed_in? },
                :expires_in => 2.days

  caches_action :show,
                :cache_path => proc {
                  topic = Entry.find params[:topic]
                  Digest::MD5.hexdigest "#{request.path}|#{params.to_json}|#{topic.updated_at}|#{topic.linked ? topic.linked.updated_at : ''}|#{json?}"
                },
                :unless => proc { user_signed_in? },
                :expires_in => 2.days

  # главная страница сайта и форум
  def index
    @page = (params[:page] || 1).to_i

    topics = case @section[:permalink]
      when AllSection[:permalink]
        if user_signed_in?
          subscriptions = Subscription.where(user_id: current_user.id, target_type: GroupComment.name).select(:target_id).map(&:target_id)
          Entry.where("type != ? or (type = ? and id in (?))", GroupComment.name, GroupComment.name, subscriptions)
        else
          Entry.where.not(type: GroupComment.name)
        end

      when FeedSection[:permalink]
        Entry.where(id: Subscription.where(user_id: current_user.id, target_type: Entry::Types).select(:target_id).map(&:target_id))

      when Section::News[:permalink]
        Entry.where(type: [AnimeNews.name, MangaNews.name])

      else
        Entry.where(section_id: @section[:id])
    end

    linked_condition = @linked ? { linked_id: @linked.id, linked_type: @linked.class.name } : nil

    topics = topics.send(@section[:permalink] == 'news' ? :wo_episodes : :wo_generated)
        .where(linked_condition)
        .with_viewed(current_user)
        .includes(:section)
        .order_default
        .offset(topics_limit * (@page-1))
        .limit(topics_limit + 1)

    #topics = topics.visible_only unless params[:linked]
    topics = topics.to_a

    @add_postloader = topics.size > topics_limit
    @topics = topics.take(topics_limit).map do |entry|
      TopicPresenter.new({
        limit: @page == 1 ? @@first_page_comments : @@other_page_comments,
        fold_limit: 10,
        linked: @linked,
        object: entry,
        template: view_context
      })
    end

    super

    # редирект на топик, если топик в подфоруме единственный
    redirect_to topic_url(@topics.first.entry, params[:format]) and return if @linked && @topics.size == 1

    respond_to do |format|
      format.html
      format.json {
        render json: @json.merge({
          content: render_to_string('topics/index', layout: false, formats: :html),
        })
      }
      format.rss
    end
  end

  # страница топика форума
  def show
    @topic ||= Entry.with_viewed(current_user).find(params[:topic])

    # новости аниме без комментариев поисковым системам не скармливаем
    noindex if Entry::SpecialTypes.include?(@topic.class.name) && @topic.comments_count == 0

    @presenter = TopicPresenter.new(object: @topic, template: view_context, linked: @linked, limit: 20, with_user: true)
    if ((@topic.news? || @topic.review?) && params[:linked].present?) || (
        !@topic.news? && !@topic.review? && (
          @topic.to_param != params[:topic] || @topic.section.permalink != params[:section] || (@topic.linked && params[:linked] != @topic.linked.to_param && @topic.class != ContestComment)
        )
      )
      redirect_to topic_url(@topic), status: :moved_permanently and return
    end

    super

    respond_to do |format|
      format.html
      format.json {
        render json: @json.merge({
          content: render_to_string(partial: 'topics/topic', locals: { topic: @presenter }, layout: false, formats: :html),
        })
      }
      format.rss
    end
  end

  # создание нового топика
  def new
    @topic ||= Topic.new(params[:topic])

    if @section[:id] == 'news'
      @topic.type = AnimeNews.name
    end

    @topic.section_id ||= @section.id if @section.respond_to? :id
    super
    @topic.linked ||= @linked

    noindex

    respond_to do |format|
      format.html do
        render 'topics/edit'
      end
      format.json do
        render json: @json.merge({
          content: render_to_string('topics/edit', layout: false, formats: :html)
        })
      end
    end
  end

  # редактирование топика
  def edit
    @topic = Entry.find(params[:id])
    @section = @topic.section

    super

    noindex

    respond_to do |format|
      format.html do
        render 'topics/edit'
      end
      format.json do
        render json: @json.merge({
          content: render_to_string('topics/edit', layout: false, formats: :html)
        })
      end
    end
  end

  # создание топика
  def create
    linked = if params[:topic]['linked_id'].present? && params[:topic]['linked_type'].present?
      params[:topic]['linked_type'].constantize.find(params[:topic]['linked_id'])
    end

    klass = if params[:topic]['type'].present?
      "#{params[:topic]['type'].sub('News', '')}News".constantize
    else
      Topic
    end

    @topic = klass.new topic_params.merge(user: current_user, linked: linked)
    @topic.user_image_ids = (params[:wall] || []).uniq if params[:wall].present?

    if @topic.save
      # отправка уведомлений о создании комментария
      FayePublisher.publish_topic(@topic, params[:faye]) if Rails.env != 'test'

      render json: {
        notice: 'Топик создан',
        url: section_topic_path(section: @topic.section, linked: @topic.linked, topic: @topic.to_param) # path, не url!
      }
    else
      render json: @topic.errors, status: :unprocessable_entity
    end
  end

  # редактирование топика
  def update
    @topic = Entry.find(params[:id])
    raise Forbidden unless @topic.can_be_edited_by?(current_user)

    @topic.class.record_timestamps = false
    @topic.user_image_ids = (params[:wall] || []).uniq if params[:wall].present?
    @topic.linked = if params[:topic]['linked_id'].present? && params[:topic]['linked_type'].present?
      params[:topic]['linked_type'].constantize.find(params[:topic]['linked_id'])
    end

    if @topic.update_attributes params.require(:topic).permit(:text, :title)
      render json: {
        notice: 'Топик изменён',
        url: section_topic_path(section: @topic.section.to_param, linked: @linked, topic: @topic.to_param) # path, не url!
      }
    else
      render json: @topic.errors, status: :unprocessable_entity
    end
    @topic.class.record_timestamps = true
  end

  # удаление топика
  def destroy
    @topic = Entry.find(params[:id])
    raise Forbidden unless @topic.can_be_deleted_by?(current_user)
    @topic.destroy

    render json: { notice: 'Топик удален' }
  end

  # html код для тултипа
  def tooltip
    topic = Entry.find(params[:id])

    preview = TopicPresenter.new(object: topic, template: view_context, limit: 0, with_user: true)

    # превью топика отображается в формате комментария
    render partial: 'comments/comment', layout: false, object: topic, locals: { no_buttons: true }, formats: :html
  end

  # выбранные топики
  def chosen
    topics = Entry.with_viewed(current_user)
                  .where(id: params[:ids].split(',').map(&:to_i))
                  .map { |entry| TopicPresenter.new(object: entry, template: view_context, limit: @@first_page_comments) }

    render partial: 'topics/topic', collection: topics, layout: false, formats: :html
  end

private
  def topic_params
    params.require(:topic).permit(:text, :title, :section_id)
  end
end
