class CreateFavourites < ActiveRecord::Migration
  def self.up
    create_table :favourites do |t|
      t.string :artist
      t.string :title
      t.string :album

      t.integer :tracknr, default: 0

      t.integer :user_id
      t.integer :track_id

      t.column :search_vector, 'tsvector'

      t.timestamps
    end

    add_index :favourites, :user_id
    add_index :favourites, :track_id

    execute <<-EOS
      CREATE INDEX favourites_search_index ON favourites USING gin(search_vector)
    EOS

    execute <<-EOS
      CREATE TRIGGER favourites_vector_update BEFORE INSERT OR UPDATE
      ON favourites
      FOR EACH ROW EXECUTE PROCEDURE
        tsvector_update_trigger(
          search_vector, 'pg_catalog.english',
          artist, title, album
        );
    EOS
  end

  def self.down
    drop_table :favourites
  end
end
