defmodule Trivia.SupervisorDePartidas do
  @moduledoc """
  Supervisor dinámico encargado de gestionar procesos de partidas (`Trivia.Partida`).

  Cada partida es un proceso independiente, iniciado bajo este supervisor.
  Ofrece funciones para:

    * Iniciar una nueva partida (`iniciar_partida/1`)
    * Listar los PID de todas las partidas activas (`listar_pids_activos/0`)

  Este módulo **no** almacena estado propio; delega todo al `DynamicSupervisor`.
  """

  alias Trivia.Partida

  @nombre_supervisor Trivia.SupervisorDePartidas

  def iniciar_partida(argumentos_partida) do
    DynamicSupervisor.start_child(@nombre_supervisor, {Partida, argumentos_partida})
  end

  def listar_pids_activos do
    DynamicSupervisor.which_children(@nombre_supervisor)
    |> Enum.flat_map(fn
      {_identificador, pid, _tipo, _modulos} when is_pid(pid) ->
        [pid]

      _otra_entrada ->
        []
    end)
  end
end
