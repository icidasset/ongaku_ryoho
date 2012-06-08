class OngakuRyoho.Views.SourceList extends Backbone.View
  
  #
  #  Initialize
  #
  initialize: () =>
    @collection = Sources
    @collection.on("reset", this.render)



  #
  #  Render
  #
  render: () =>
    
    # opening html
    html = "<form><div class=\"source-list\"><ol>"
    
    # sources html
    @collection.each((source) ->
      source_view = new OngakuRyoho.Views.Source({ model: source })
      html += source_view.render().el.innerHTML
    , this)
    
    # ending html
    html += "</ol></div></form>"
    
    # set html
    this.$el.html(html)
    
    # chain
    return this
