class ScreensController < ApplicationController
  before_action :require_adult
  before_action :set_screen, only: %i[show edit update destroy]

  def index
    @screens = Current.household.screens.order(:created_at)
  end

  def new
    @screen = Current.household.screens.new
  end

  def create
    @screen = Current.household.screens.new(screen_params)
    if @screen.save
      redirect_to @screen, notice: "Screen added. Open its enrollment link on the device."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show; end

  def edit; end

  def update
    if @screen.update(screen_params)
      redirect_to @screen, notice: "Screen settings saved. The screen reloads with them."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @screen.destroy
    redirect_to screens_path, notice: "Screen removed. It is signed out."
  end

  private

  def set_screen
    @screen = Current.household.screens.find(params[:id])
  end

  def screen_params
    params.expect(screen: %i[name night_from night_to night_style default_view reload_hour])
  end
end
