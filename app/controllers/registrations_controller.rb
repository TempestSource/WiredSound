class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome to WiredSound, #{@user.username}!"
    else
      # This renders the form again with error messages
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    # .require(:user) tells Rails to look inside the "user" wrapper in the params
    params.require(:user).permit(:username, :password, :password_confirmation)
  end
end