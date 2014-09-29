class CharacterDecorator < PersonDecorator
  instance_cache :favoured, :favoured?, :seyu, :changes, :all_animes, :all_mangas, :limited_animes, :limited_mangas

  def url
    h.character_url object
  end

  def favoured
    FavouritesQuery.new.favoured_by object, 12
  end

  def favoured?
    h.user_signed_in? && h.current_user.favoured?(object)
  end

  def seyu
    object.seyu.to_a
  end

  def job_title
    "Персонаж #{[animes.any? ? 'аниме' : nil, mangas.any? ? 'манги' : nil].compact.join(' и ')}"
  end

  # презентер косплея
  def cosplay
    @cosplay ||= AniMangaPresenter::CosplayPresenter.new object, h
  end

  # презентер пользовательских изменений
  def changes
    AniMangaDecorator::ChangesDecorator.new object
  end

  def animes limit = nil
    decorated_entries object.animes.limit(limit)
  end

  def mangas limit = nil
    decorated_entries object.mangas.limit(limit)
  end

private
  def decorated_entries query
    query
      .decorate
      .sort_by {|v| v.aired_on || v.released_on || DateTime.new(2001) }
  end
end
