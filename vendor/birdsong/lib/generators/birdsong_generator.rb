class BirdsongGenerator < Rails::Generators::Base
  source_root(File.expand_path(File.dirname(__FILE__)))
  def copy_initializer
    copy_file "birdsong.rb", "config/initializers/birdsong.rb"
  end
end
