defmodule Shadowfax.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels) do
      add :name, :string, null: false
      add :description, :text
      add :topic, :string
      add :is_private, :boolean, default: false, null: false
      add :is_archived, :boolean, default: false, null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)
      add :max_members, :integer
      add :invite_code, :string

      timestamps()
    end

    create unique_index(:channels, [:name])
    create index(:channels, [:created_by_id])
    create index(:channels, [:is_private])
    create unique_index(:channels, [:invite_code])
  end
end
