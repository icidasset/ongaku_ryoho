class OngakuRyoho.Classes.Views.MessageCenter extends Backbone.View

  #
  #  Events
  #
  events: () ->
    "click .message" : @group.machine.message_click_handler



  #
  #  Initialize
  #
  initialize: () ->
    super()

    # this element
    this.setElement($("#message-center"))

    # collection events
    @group.collection.on("add", this.add_message)
    @group.collection.on("remove", this.remove_message)



  #
  #  Add & remove
  #
  add_message: (message) =>
    view = new OngakuRyoho.Classes.Views.Message({ model: message })

    # $message
    $message = view.render().$el

    # append html
    this.$el.append($message)

    # fade in message
    $message.fadeIn(500)

    # loading animation?
    if message.get("loading")
      Helpers.add_loading_animation(
        $message.children("div:first-child")[0]
      )



  remove_message: (message) =>
    this.$el.find(".message[rel=\"#{message.cid}\"]")
        .fadeOut 500, () -> $(this).remove()
