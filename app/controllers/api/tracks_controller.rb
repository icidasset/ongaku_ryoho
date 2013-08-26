class Api::TracksController < ApplicationController
  before_filter :require_login
  layout false

  def index
    options = get_options_from_params

    # available source ids
    available_source_ids = options[:source_ids]

    # select tracks
    if available_source_ids
      tracks_box = select_tracks(available_source_ids, options)
    else
      tracks_box = {
        tracks: [],
        total: 0
      }
    end

    # render
    only = %w(artist title album tracknr filename location url id favourite_id source_id)

    tracks = tracks_box[:tracks].map do |track|
      attrs = track.attributes.select do |k, v|
        only.include?(k)
      end
      attrs["available"] = track.available
      attrs
    end

    render json: Oj.dump({
      page: options[:page],
      per_page: options[:per_page],
      total: tracks_box[:total],
      models: tracks
    }, mode: :compat)
  end


private


  #
  #  Parameter processing
  #
  def get_options_from_params
    options = {
      source_ids: clean_up_source_ids(params[:source_ids]),
      filter: get_filter_value(params[:searches]),
      page: params[:page].to_i,
      per_page: params[:per_page].to_i,
      sort_by: params[:sort_by].try(:to_sym),
      sort_direction: params[:sort_direction].try(:upcase),
      select_favourites: (params[:favourites] == "true"),
      playlist: params[:playlist]
    }

    # add options that depend on other options
    options = options.merge(
      offset: (options[:page] - 1) * options[:per_page]
    )

    # return
    options
  end


  def get_filter_value(searches)
    excludes = []

    searches = (searches || []).map do |search_query|
      search_query = view_context.sanitize(search_query)
      search_query = search_query
        .gsub(/\:|\*|\&|\||\'|\"|\+/, "")
        .strip
        .gsub(/^\!+\s*/, "!")
        .gsub(" ", "+")

      if search_query.size == 0
        nil
      elsif search_query[0] == "!"
        search_query = "!" + search_query[1..-1].gsub("!", "")
        excludes << "#{search_query}:*"
        nil
      else
        search_query = search_query.gsub("!", "")
        "#{search_query}:*"
      end
    end.compact

    # filter
    filter = ""
    filter << "(#{searches.join(" | ")})" if searches.length > 0
    filter << " & " if searches.length > 0 && excludes.length > 0
    filter << "(#{excludes.join(" & ")})" if excludes.length > 0
    filter
  end


  def clean_up_source_ids(source_ids)
    user_source_ids = current_user.sources.pluck(:id)
    source_ids.split(",").map do |source_id|
      id = source_id.to_i
      id if id > 0 && user_source_ids.include?(id)
    end.compact
  end


  #
  #  Select tracks
  #
  def select_tracks(available_source_ids, options)
    filter = !options[:filter].blank?
    select_favourites = options[:select_favourites]
    playlist = get_playlist(options[:playlist])

    # check
    if available_source_ids.empty? and !select_favourites
      return { tracks: [], total: 0 }
    end

    # conditions
    conditions, condition_arguments = [], []

    if select_favourites
      conditions << "user_id = ?"
      condition_arguments << current_user.id
    else
      conditions << "source_id IN (?)"
      condition_arguments << available_source_ids
    end

    if filter
      conditions << "search_vector @@ to_tsquery('english', ?)"
      condition_arguments << options[:filter]
    end

    if playlist.is_a?(Playlist) && !select_favourites
      conditions.unshift "id IN (?)"
      condition_arguments.unshift playlist.track_ids
    elsif playlist.is_a?(String)
      conditions.push "location LIKE (?)"
      condition_arguments.push "#{playlist}%"
    end

    # bundle conditions
    condition_sql = conditions.join(" AND ")
    conditions = [condition_sql] + condition_arguments.compact

    # next
    args = [conditions, available_source_ids, options]
    if select_favourites then select_favourited_tracks(*args)
    else select_default_tracks(*args)
    end
  end


  def select_default_tracks(conditions, available_source_ids, options)
    order = get_sql_for_order(options[:sort_by], options[:sort_direction])

    # get tracks
    tracks = Track.find(:all, {
      offset: options[:offset],
      limit: options[:per_page],
      conditions: conditions,
      order: order
    })

    total = if options[:offset] == 0 && tracks.length < options[:per_page]
      tracks.length
    else
      Track.count(conditions: conditions)
    end

    # return
    { tracks: tracks, total: total }
  end


  def select_favourited_tracks(conditions, available_source_ids, options)
    order = get_sql_for_order(options[:sort_by], options[:sort_direction])

    # conditions
    conditions[0] << " AND track_ids ?| ARRAY[?]"
    conditions << available_source_ids.map(&:to_s).join(",")

    # get favourites
    favourites = Favourite.find(:all, {
      offset: options[:offset],
      limit: options[:per_page],
      conditions: conditions,
      order: order
    })

    total = if options[:offset] == 0 && favourites.length < options[:per_page]
      favourites.length
    else
      Favourite.count(conditions: conditions)
    end

    # process favourites
    unavailable_track_ids = []
    track_ids = []
    tracks_placeholder = favourites.map(&:id)

    source_ids = current_user.sources.all.map(&:id)
    unavailable_source_ids = source_ids - available_source_ids

    favourites.each_with_index do |f, idx|
      track_id = nil

      unless f.track_ids.keys.empty?
        track_id = get_track_id_from_track_ids_hash(f.track_ids, available_source_ids)
        track_ids << track_id if track_id

        unless track_id
          track_id = get_track_id_from_track_ids_hash(f.track_ids, unavailable_source_ids)
          unavailable_track_ids << track_id if track_id
        end
      end

      unless track_id
        imaginary_track = Track.new({
          title: f.title,
          artist: f.artist,
          album: f.album,
          tracknr: 0,
          genre: ""
        })

        imaginary_track.favourite_id = f.id
        imaginary_track.available = false

        index = tracks_placeholder.index(f.id)
        tracks_placeholder[index] = imaginary_track
      end
    end

    # get unavailable tracks
    _unavailable_tracks = Track.where(id: unavailable_track_ids)
    _unavailable_tracks.each do |ut|
      ut.available = false

      index = tracks_placeholder.index(ut.favourite_id)
      tracks_placeholder[index] = ut

      track_ids.delete(ut.id)
    end

    # get available tracks
    _tracks = Track.where(id: track_ids)
    _tracks.each do |t|
      index = tracks_placeholder.index(t.favourite_id)
      tracks_placeholder[index] = t
    end

    # clean up placeholder
    tracks_placeholder = tracks_placeholder.map do |t|
      t.is_a?(Fixnum) ? nil : t
    end.compact

    # return
    { tracks: tracks_placeholder, total: total }
  end


  #
  #  Select tracks / Helpers
  #
  def get_playlist(playlist)
    if playlist
      if playlist.index("/") then playlist
      elsif playlist.to_i === 0 then false
      else Playlist.find(playlist.to_i)
      end
    end
  end


  def get_sql_for_order(sort_by, direction="ASC")
    order = case sort_by
    when :title
      "LOWER(title), tracknr, LOWER(artist), LOWER(album)"
    when :album
      "LOWER(album), tracknr, LOWER(artist), LOWER(title)"
    else
      "LOWER(artist), LOWER(album), tracknr, LOWER(title)"
    end

    if direction == "DESC"
      order.split(", ").map { |o| "#{o} DESC" }.join(", ")
    else
      order
    end
  end


  def get_track_id_from_track_ids_hash(track_ids, source_ids)
    track_id = nil

    # loop
    source_ids.each do |source_id|
      if ids_array_string = track_ids[source_id.to_s]
        if tid = ids_array_string.split(",").first
          track_id = tid
          break
        end
      end
    end

    # return
    track_id
  end

end
