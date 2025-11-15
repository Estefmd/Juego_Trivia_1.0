defmodule ProyectoTriviaEsMixTest do
  use ExUnit.Case
  test "crear partida y unirse" do
    {:ok, _} = ProyectoTriviaEs.Aplicacion.start(:normal, [])
    {:ok, _pid} = Trivia.Servidor.crear_partida("Ana", "ciencia", cantidad_preguntas: 5)
    id = Trivia.Servidor.listar_partidas() |> hd() |> Map.fetch!(:identificador)
    assert {:ok, :unido} == Trivia.Servidor.unirse_a_partida_por_id(id, "Luis")
  end
end
