if defined? Bugsnag
  Bugsnag.configure do |config|
    config.api_key = '1c291a76810dd8610cfea663b21c7785'

    Shikimori::IGNORED_EXCEPTIONS
      .map { |v| v.constantize rescue NameError }
      .reject { |v| v == NameError }
      .each do |klass|
        config.ignore_classes << klass
      end
  end
end
