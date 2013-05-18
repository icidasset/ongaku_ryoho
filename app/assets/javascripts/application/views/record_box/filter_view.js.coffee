class OngakuRyoho.Classes.Views.RecordBox.Filter extends Backbone.View

  #
  #  Events
  #
  events: () ->
    "click .add-button.favourites" : @group.machine.toggle_favourites
    "click .item.favourites" : @group.machine.disable_favourites



  #
  #  Initialize
  #
  initialize: () ->
    super

    # elements
    $btn = OngakuRyoho.RecordBox.Navigation.view.$el.find(".filter")
    this.setElement($btn[0])

    # templates
    @filter_item_template = Helpers.get_template("filter-item")

    # model events
    @group.model.on("change", this.render)
    @group.model.on("change", @group.machine.fetch_tracks)
    @group.model.on("change:sort_by", @group.machine.sort_by_change_handler)
    @group.model.on("change:sort_direction", @group.machine.sort_by_change_handler)

    # TODO
    this.render()



  #
  #  Render
  #
  render: () =>
    model = @group.model
    box_element = this.$el.children(".box")[0]
    fragment = document.createDocumentFragment()
    item_element = document.createElement("a")
    item_element.className = "item"

    # playlist
    # -> todo

    # search
    # -> todo
    item_element_clone = item_element.cloneNode(true)
    item_element_clone.classList.add("search")
    item_element_clone.innerHTML = @filter_item_template({
      text: "Justice",
      icon: "&#128269;"
    })

    fragment.appendChild(item_element_clone)

    item_element_clone = item_element.cloneNode(true)
    item_element_clone.classList.add("search")
    item_element_clone.innerHTML = @filter_item_template({
      text: "Boys Noize",
      icon: "&#128269;"
    })

    fragment.appendChild(item_element_clone)

    # favourites
    if model.get("favourites")
      item_element_clone = item_element.cloneNode(true)
      item_element_clone.classList.add("favourites")
      item_element_clone.innerHTML = @filter_item_template({
        text: "Favourites only",
        icon: "&#9733;"
      })

      fragment.appendChild(item_element_clone)

    # add fragment to box
    box_element.innerHTML = ""
    box_element.appendChild(fragment)

