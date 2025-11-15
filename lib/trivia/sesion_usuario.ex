defmodule Trivia.SesionDeUsuario do
  @moduledoc """
  Módulo encargado de almacenar el estado de las sesiones de los usuarios.

  Este módulo funciona como un pequeño repositorio en memoria mediante `Agent`.

  Estructura recomendada del valor por usuario:
      %{
        conectado: true | false,
        otros_campos: ...
      }

  Se inicia automáticamente desde el supervisor raíz de la aplicación.
  """

  use Agent

  def start_link(_argumentos) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put(nombre_usuario, valor_sesion) do
    Agent.update(__MODULE__, fn sesiones ->
      Map.put(sesiones, nombre_usuario, valor_sesion)
    end)
  end

  def get(nombre_usuario) do
    Agent.get(__MODULE__, fn sesiones ->
      Map.get(sesiones, nombre_usuario)
    end)
  end
end
