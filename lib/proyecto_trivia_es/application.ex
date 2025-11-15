defmodule ProyectoTriviaEs.Aplicacion do
  @moduledoc """
  Punto de arranque principal de la aplicación Trivia.

  Inicia:
    * Un `DynamicSupervisor` para crear partidas de trivia de manera dinámica.
    * Un `Agent` centralizado para manejar las sesiones activas de los usuarios.

  Esta estructura permite concurrencia, procesos aislados y recuperación automática.
  """

  use Application

  @impl true
  def start(_tipo, _argumentos) do
    children = [
      {DynamicSupervisor,
       strategy: :one_for_one,
       name: Trivia.SupervisorDePartidas},

      %{
        id: Trivia.SesionDeUsuario,
        start: {
          Agent,
          :start_link,
          [fn -> %{} end, [name: Trivia.SesionDeUsuario]]
        }
      }
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: ProyectoTriviaEs.SupervisorRaiz
    )
  end
end
