require "rubygems"
require "sinatra"
require "builder"
require "haml"
require "sass"
require "nokogiri"
require 'open4'

require "lib/cache"
require "lib/configuration"
require "lib/models"

set :cache_enabled, Nesta::Configuration.cache

helpers do
  def set_from_config(*variables)
    variables.each do |var|
      instance_variable_set("@#{var}", Nesta::Configuration.send(var))
    end
  end
  
  def set_from_page(*variables)
    variables.each { |var| instance_variable_set("@#{var}", @page.send(var)) }
  end
  
  def set_title(page)
    if page.respond_to?(:parent) && page.parent
      @title = "#{page.heading} - #{page.parent.heading}"
    else
      @title = "#{page.heading} - #{Nesta::Configuration.title}"
    end
  end
  
  def no_widow(text)
    text.split[0...-1].join(" ") + "&nbsp;#{text.split[-1]}"
  end
  
  def set_common_variables
    @menu_items = Page.menu_items
    #raise @menu_items.inspect
    @site_title = Nesta::Configuration.title
    @motto = Nesta::Configuration.subtitle
    set_from_config(:google_analytics_code, :title, :subtitle)
    @heading = @title
  end

  def url_for(page)
    File.join(base_url, page.path)
  end
  
  def base_url
    url = "http://#{request.host}"
    request.port == 80 ? url : url + ":#{request.port}"
  end  
  
  def nesta_atom_id_for_page(page)
    published = page.date.strftime('%Y-%m-%d')
    "tag:#{request.host},#{published}:#{page.abspath}"
  end
  
  def atom_id(page = nil)
    if page
      page.atom_id || nesta_atom_id_for_page(page)
    else
      "tag:#{request.host},2009:/"
    end
  end
  
  def format_date(date)
    date.strftime("%d %B %Y")
  end
  
  def haml(template, options = {}, locals = {})
    super(template, options.merge(render_options(:haml, template)), locals)
  end
  
  def sass(template, options = {}, locals = {})
    super(template, options.merge(render_options(:sass, template)), locals)
  end
  
  def erb(template, options = {}, locals = {})
    super(template, options.merge(render_options(:erb, template)), locals)
  end
end

def highlight(text)
  tag = 'highlight'
  attribute = 'lang'

  if system("which pygmentize > /dev/null")
    bin = `which pygmentize`.chomp
  else
    raise Exception, "Pygmentize is missing"
  end

  document = Nokogiri::HTML(text)
  nodes = document.css(tag)
  nodes.each do |node|
    lang = node.attribute(attribute).nil? ? 'bash' : node.attribute(attribute).value    
    
    output = ''
    Open4.popen4("#{bin} -l #{lang} -f html") do |pid, stdin, stdout, stderr|
      stdin.puts node.content
      stdin.close
      output = stdout.read.strip
      [stdout, stderr].each { |io| io.close }
    end

    node.replace(Nokogiri::HTML(output).css("div.highlight").first)
  end

  document.to_s
end

not_found do
  set_common_variables
  haml(:not_found)
end

error do
  set_common_variables
  haml(:error)
end unless Sinatra::Application.environment == :development

# If you want to change Nesta's behaviour, you have two options:
#
# 1. Edit the code. You can merge in future upstream changes with git.
# 2. Add code to local/app.rb that overrides the default behaviour,
#    leaving the default files untouched (no "tricky" merging required).
#
# Neither way is necessarily *better* than the other; it's up to you to
# choose the most appropriate course of action for your site. Merging future
# changes in will typically be a straightforward task, but you may find
# the ./local directory to be an easy way to manage more significant
# changes to Nesta's behaviour that are likely to conflict with future
# changes to the main code base.
#
# Note that you can modify the behaviour of any of the default objects
# in local/app.rb, or replace any of the default view templates by
# creating replacements of the same name in local/views.
begin
  require File.join(File.dirname(__FILE__), "local", "app")
rescue LoadError
end

def render_options(engine, template)
  local_views = File.join("local", "views")
  if File.exist?(File.join(local_views, "#{template}.#{engine}"))
    { :views => local_views }
  else
    {}
  end
end

get "/css/:sheet.css" do
  content_type "text/css", :charset => "utf-8"
  cache sass(params[:sheet].to_sym)
end

get "/" do
  set_common_variables
  set_from_config(:title, :subtitle, :description, :keywords)
  @heading = @title
  @title = "#{@title} - #{@subtitle}"
  @articles = Page.find_articles[0..7]
  @body_class = "home"
  cache haml(:index)
end

get "/blog" do
  set_common_variables
  set_from_config(:title, :subtitle, :description, :keywords)
  @heading = @title
  @title = "#{@title} - #{@subtitle}"
  @articles = Page.find_articles[0..7]
  @body_class = "home"
  cache haml(:blog)
end

get %r{/attachments/([\w/.-]+)} do
  file = File.join(
      Nesta::Configuration.attachment_path, params[:captures].first)
  send_file(file, :disposition => nil)
end

get "/articles.xml" do
  content_type :xml, :charset => "utf-8"
  set_from_config(:title, :subtitle, :author)
  @articles = Page.find_articles.select { |a| a.date }[0..9]
  cache builder(:atom)
end

get "/sitemap.xml" do
  content_type :xml, :charset => "utf-8"
  @pages = Page.find_all
  @last = @pages.map { |page| page.last_modified }.inject do |latest, this|
    this > latest ? this : latest
  end
  cache builder(:sitemap)
end

get "*" do
  set_common_variables
  @page = Page.find_by_path(File.join(params[:splat]))
  raise Sinatra::NotFound if @page.nil?
  set_title(@page)
  set_from_page(:description, :keywords)
  cache haml(:page)
end
