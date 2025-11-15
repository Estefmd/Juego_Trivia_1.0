defmodule ProyectoTriviaEs.MixProject do
  use Mix.Project

  def project do
    [
      app: :proyecto_trivia_es,
      version: "1.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {ProyectoTriviaEs.Aplicacion, []},
      extra_applications: [:logger]
    ]
  end

  defp deps, do: []
end
