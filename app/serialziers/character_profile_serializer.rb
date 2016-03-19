class CharacterProfileSerializer < CharacterSerializer
  attributes :altname, :japanese, :description, :description, :description_html,
    :favoured?, :thread_id, :updated_at

  has_many :seyu
  has_many :animes
  has_many :mangas

  def thread_id
    object.topic.id
  end

  def description
    if scope.ru_domain?
      object[:description_ru] || object[:description_en]
    else
      object[:description_en]
    end
  end
end
