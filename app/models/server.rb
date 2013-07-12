class Server < Source
  attr_accessor :location

  #
  #  Worker
  #
  def self.worker
    ServerJob
  end


  #
  #  Override ActiveRecord::Base.new
  #
  def self.new(attributes=nil, options={}, user_id)
    location = attributes.delete(:location)
    location = "http://#{location}" unless location.include?('http://')
    location << (location.end_with?('/') ? '' : '/')

    attributes[:name] = location.gsub('http://', '').gsub('/', '')
    attributes[:configuration] = { location: location }
    attributes[:processed] = false

    existing_server = Server.all.select { |s|
      s.configuration["location"] == location
    }.first

    unless existing_server
      server = super(attributes, options)
      server.user_id = user_id
      server
    end
  end


  #
  #  Update
  #
  def update_with_selected_attributes(attributes_from_client)
    attrs = attributes_from_client.select do |k, v|
      %w(name configuration activated).include?(k.to_s)
    end

    self.update_attributes(attrs)
  end


  #
  #  Utility functions
  #
  def self.add_new_tracks(server, new_tracks)
    return unless new_tracks.present?

    # attributes -> models
    new_track_models = new_tracks.map do |tags|
      tags["tracknr"] = tags.delete("track") || ""
      tags["url"] = server.configuration["location"] + tags["location"]

      tags.each do |tag, value|
        condition = value.is_a?(String) and value.length > 255
        tags[tag] = value[0...255] if condition
      end

      new_track_model = Track.new(tags)
      new_track_model.source_id = server.id

      new_track_model
    end

    # save models
    ActiveRecord::Base.transaction do
      new_track_models.each(&:save)
    end
  end


  def self.remove_tracks(server, missing_files)
    return unless missing_files.present?

    # collect tracks
    tracks = Track.where(location: missing_files, source_id: server.id)
    tracks_with_favourites = tracks.where("favourite_id IS NOT NULL").all

    # remove track_id from related favourites
    tracks_with_favourites.each do |track|
      track.favourite.track_id = nil
      track.favourite.save
    end

    # destroy tracks
    tracks.destroy_all
  end


  #
  #  Label
  #
  def label
    label = if name.blank? and configuration["location"]
      configuration["location"]
    else
      name
    end

    "#{label}"
  end


  #
  #  Check if the server is available
  #  and doesn't return any errors
  #
  def available?
    sess = Patron::Session.new

    begin
      response = sess.head(self.configuration["location"])
    rescue
      return false
    end

    return response.status == 200
  end

end
