class Settings::PeopleController < Settings::BaseController
  before_action { @entities = HomeAssistant.configured? ? HomeAssistant.entities(%w[person device_tracker]) : [] }
  before_action :set_person, only: %i[edit update destroy move]

  def index
    @people = @household.people
  end

  def new
    @person = @household.people.new(color: "#2D5BFF")
  end

  def create
    @person = @household.people.new(person_params)
    @person.save ? saved(settings_people_path, "#{@person.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @person.update(person_params) ? saved(settings_people_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @person.destroy
    saved(settings_people_path, "#{@person.name} removed.")
  end

  def move
    @person.move!(params[:direction], @household.people)
    saved(settings_people_path)
  end

  private

  def set_person
    @person = @household.people.find(params[:id])
  end

  def person_params
    params.expect(person: %i[name color kid email nicknames status presence_entity pin]).tap { |p| p.delete(:pin) if p[:pin].blank? }
  end
end
