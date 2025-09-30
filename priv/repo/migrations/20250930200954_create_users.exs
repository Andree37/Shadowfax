defmodule Shadowfax.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string, null: false
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :avatar_url, :string
      add :status, :string, default: "offline"
      add :is_online, :boolean, default: false
      add :last_seen_at, :naive_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
