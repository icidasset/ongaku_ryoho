OngakuRyoho.Views.TrackView = Backbone.View.extend({
  
  
  /**************************************
   *  Initialize
   */
  initialize : function() {
    _.bindAll(this, 'render');
    
    this.template = _.template($('#track_template').html());
  },
  
  
  /**************************************
   *  Render
   */
  render : function() {
    $(this.el).html(this.template( this.model.toJSON() ));
    $(this.el).children('.track').attr('rel', this.model.cid);
    
    return this;
  }
  
  
});
