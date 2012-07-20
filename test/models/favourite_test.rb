require "test_helper"

describe Favourite do
  subject { Favourite.new }

  it { must belong_to(:user) }

  it { must allow_mass_assignment_of(:artist) }
  it { must allow_mass_assignment_of(:title) }
  it { must allow_mass_assignment_of(:album) }
  it { must allow_mass_assignment_of(:track_id) }

  it { must validate_presence_of(:artist) }
  it { must validate_presence_of(:title) }
  it { must validate_presence_of(:album) }
end
