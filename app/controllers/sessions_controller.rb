class SessionsController < ApplicationController
  def new
    # Renders app/views/sessions/new.html.erb
  end

  def create
    user = User.authenticate(params[:username], params[:password])
    if user
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in as #{user.username}"
    else
      flash.now[:alert] = "Invalid credentials"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil

    redirect_to root_path, notice: "You have been logged out.", status: :see_other
  end
end