class AnimesCollection::View < ViewObjectBase
  vattr_initialize :klass

  instance_cache :collection, :results, :filtered_params
  delegate :page, :pages_count, to: :results

  def collection
    if season_page?
      results.collection.each_with_object({}) do |(key, entries), memo|
        memo[key] = entries.map(&:decorate)
      end
    else
      results.collection.map(&:decorate)
    end
  end

  def season_page?
    !recommendations? &&
      h.params[:season].present? &&
      !!h.params[:season].match(/^([a-z]+_\d+,?)+$/)
  end

  def recommendations?
    h.params[:controller] == 'recommendations'
  end

  def cache?
    !recommendations? && !h.params[:mylist]
  end

  def cache_key
    h.params
      .except(:format, :controller, :action)
      .sort_by(&:first)
      .inject([klass.name]) { |memo, (k, v)| memo.push "#{k}:#{v}" }
  end

  def cache_expires_in
    h.params[:season] || h.params[:status] ? 1.day : 1.week
  end

  def url changed_params
    h.url_for filtered_params.merge(changed_params)
  end

  def prev_page_url
    h.url_for filtered_params.merge(page: page - 1) if page > 1
  end

  def next_page_url
    h.url_for filtered_params.merge(page: page + 1) if page < pages_count
  end

  def filtered_params
    h.params.except(
      :format, :template, :is_adult,
      AnimesCollection::RecommendationsQuery::IDS_KEY,
      AnimesCollection::RecommendationsQuery::EXCLUDE_IDS_KEY
    )
  end

private

  def results
    Rails.cache.fetch cache_key, expires_in: cache_expires_in do
      if recommendations?
        AnimesCollection::RecommendationsQuery.new(klass, h.params).fetch
      elsif season_page?
        AnimesCollection::SeasonQuery.new(klass, h.params).fetch
      else
        AnimesCollection::PageQuery.new(klass, h.params).fetch
      end
    end
  end
end
