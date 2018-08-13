# Adding Multiple Images to your Model

Refinery offers a generator which allows an engine/model to have fields which are single images. It doesn't supply anything out-of-the-box to allow a model to have a collection of images.

However the extension *Refinerycms-page-images* implements an image collection for the *Refinery::Page* model which can be extended to other models.

*Thanks to [Prokop Simek](:https://github.com/prokopsimek) who detailed this method [here](:https://github.com/refinery/refinerycms-page-images/issues/111).*

## What you get

When you have completed these steps your model/engine you will be able to add and remove images from an instance of your model using the same tabbed interface used by Refinery::Pages.

In a view you will have access to a collection of images (*@model.images*).

### Pre-requisites

* Refinerycms
* Refinerycms-page-images
* an engine or extension to work with (the examples will use `Shows`)


##### Configure Refinerycms-page-images

````Ruby
#app/config/initializers/refinery/page_images.rb
Refinery::PageImages.configure do |config|
  config.captions = true
  config.enable_for = [
    {model: "Refinery::Page", tab: "Refinery::Pages::Tab"},
    {model: "Refinery::Show", tab: "Refinery::Shows::Tab"}
  ]
  config.wysiwyg = true
end
````

#####  Add page-images to your model

````Ruby
#vendor/extensions/shows/app/models/refinery/shows/show.rb
module Refinery
  module Shows
    class Show < Refinery::Core::BaseModel

      self.table_name = 'refinery_shows'
      validates :title, :presence => true, :uniqueness => true
      has_many_page_images
    end
  end
end
````

##### Define Tabs

````Ruby
#vendor/extensions/shows/lib/refinery/shows/tabs.rb
 module Refinery
  module Shows
    class Tab
      attr_accessor :name, :partial

      def self.register(&block)
        tab = self.new

        yield tab

        raise "A tab MUST have a name!: #{tab.inspect}" if tab.name.blank?
        raise "A tab MUST have a partial!: #{tab.inspect}" if tab.partial.blank?
      end

      protected

        def initialize
          ::Refinery::Shows.tabs << self # add me to the collection of registered tabs
        end
    end
  end
 end
 ````

##### Load and Initialize Tabs
````Ruby
# vendor/extensions/shows/lib/refinery/shows.rb
require 'refinerycms-core'
module Refinery
  autoload :ShowsGenerator, 'generators/refinery/shows_generator'

  module Shows
    require 'refinery/shows/engine'

    autoload :Tab, 'refinery/shows/tabs'

    class << self
      attr_writer :root
      attr_writer :tabs

      def root
        @root ||= Pathname.new(File.expand_path('../../../', __FILE__))
      end

      def tabs
        @tabs ||= []
      end

      def factory_paths
        @factory_paths ||= [ root.join('spec', 'factories').to_s ]
      end
    end
  end
end
````


##### Modify the admin view
````Ruby
# vendor/extensions/shows/app/views/refinery/admin/_form.html.erb
<%= form_for [refinery, :shows_admin, @show] do |f| -%>
  <%= render '/refinery/admin/error_messages',
              :object => @show,
              :include_object_name => true %>

  <div class='field'>
    <%= f.label :title -%>
    <%= f.text_field :title, :class => 'larger widest' -%>
  </div>

  <div class='field'>
    <div id='page-tabs' class='clearfix ui-tabs ui-widget ui-widget-content ui-corner-all'>
      <ul id='page_parts'>
        <li class='ui-state-default ui-state-active'>
          <%= link_to 'Blurb', "#page_part_blurb" %>
        </li>
        <% Refinery::Shows.tabs.each_with_index do |tab, tab_index| %>
          <li class='ui-state-default' id="custom_<%= tab.name %>_tab">
            <%= link_to tab.name.titleize, "#custom_tab_#{tab_index}" %>
          </li>
        <% end %>
      </ul>

      <div id='page_part_editors'>
        <% part_index = -1 %>
          <%= render 'form_part', :f => f, :part_index => (part_index += 1) -%>
        <% Refinery::Shows.tabs.each_with_index do |tab, tab_index| %>
          <div class='page_part' id='<%= "custom_tab_#{tab_index}" %>'>
            <%= render tab.partial, :f => f %>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <%= render '/refinery/admin/form_actions', :f => f,
             :continue_editing => false,
             :delete_title => t('delete', :scope => 'refinery.shows.admin.shows.show'),
             :delete_confirmation => t('message', :scope => 'refinery.admin.delete', :title => @show.title) -%>
<% end -%>
````

##### Add strong parameters for the new fields

Part 1. Write a decorator.

````Ruby
#vendor/extensions/shows/app/decorators/controllers/refinery/admin/shows_controller_decorator.rb
module RefineryPageImagesShowsControllerDecorator
    def permitted_show_params
      # Hand the case where all images have been deleted
      params[:show][:images_attributes]={} if params[:show][:images_attributes].nil?
      super <<  [images_attributes: [:id, :caption, :image_page_id]]
    end
  end

Refinery::Shows::Admin::ShowsController.send :prepend, RefineryPageImagesShowsControllerDecorator
````

Part 2. Modify the ShowsController (if required)

Some `ModelsControllers` will require this update. It doesn't change the controller itself, but makes it easier to extend the initial list of permitted fields.

````Ruby
#vendor/extensions/shows/app/controllers/refinery/shows/admin/shows_controller.rb
module Refinery
  module Shows
    module Admin
      class ShowsController < ::Refinery::AdminController

        crudify :'refinery/shows/show'

        def show_params
          params.require(:show).permit(permitted_show_params)
        end

       # private

        # Only allow a trusted parameter "white list" through.
        def permitted_show_params
          [:title, :blurb]
        end

      end
    end
  end
end

````