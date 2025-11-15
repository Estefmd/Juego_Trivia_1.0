defmodule Trivia.BancoDePreguntas do
  @moduledoc """
  Módulo encargado de cargar, parsear y filtrar las preguntas del archivo
  `data/questions.dat`.

  Cada línea del archivo debe tener el siguiente formato CSV:

      categoria,texto_pregunta,opcionA,opcionB,opcionC,opcionD,respuesta_correcta
  """

  @archivo Path.expand("data/questions.dat", File.cwd!())
  @external_resource @archivo

  def asegurar_archivo do
    File.mkdir_p!(Path.dirname(@archivo))

    unless File.exists?(@archivo) do
      File.write!(@archivo, "")
    end

    :ok
  end

  defp parsear_linea(linea) do
    [categoria, texto_pregunta, opcion_a, opcion_b, opcion_c, opcion_d, respuesta] =
      linea
      |> String.trim()
      |> String.split(",")

    %{
      categoria: categoria,
      texto: texto_pregunta,
      opciones: %{
        "A" => opcion_a,
        "B" => opcion_b,
        "C" => opcion_c,
        "D" => opcion_d
      },
      correcta: String.upcase(respuesta)
    }
  end

  defp leer_todas_las_preguntas do
    asegurar_archivo()

    @archivo
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&parsear_linea/1)
  end

  def aleatorias_por_categoria(categoria_buscada, cantidad) do
    leer_todas_las_preguntas()
    |> Enum.filter(fn pregunta -> pregunta.categoria == categoria_buscada end)
    |> Enum.shuffle()
    |> Enum.take(cantidad)
  end
end
