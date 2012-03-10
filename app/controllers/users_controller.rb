class UsersController < ApplicationController
  # GET 'users/new'
  def new
    @user = User.new
  end

  # POST 'users'
  def create
    @user = User.new(params[:user])
    if @user.save
      redirect_to root_url, :notice => "Signed up!"
    else
      render :new
    end
  end
end