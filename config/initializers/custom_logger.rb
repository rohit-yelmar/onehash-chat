# config/initializers/custom_logger.rb
CUSTOM_LOGGER = Logger.new(Rails.root.join('log', 'custom.log'))
CUSTOM_LOGGER.level = Logger::INFO
