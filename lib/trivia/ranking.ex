defmodule Trivia.Ranking do
  @moduledoc """
  Construye el ranking histórico de los jugadores a partir del archivo
  `data/results.log`.

  El archivo contiene bloques con el siguiente formato:

      Ganador: X
      Categoría: ciencia
      Puntajes:
      - Tefa: 30
      - Lau: 15
      ---

  Este módulo:
    * Lee todos los bloques.
    * Los convierte en estructuras manejables.
    * Acumula puntajes globales.
    * Permite obtener ranking global o por categoría.
  """

  @archivo Path.expand("data/results.log", File.cwd!())

  defp asegurar_archivo do
    File.mkdir_p!(Path.dirname(@archivo))

    unless File.exists?(@archivo) do
      File.write!(@archivo, "")
    end

    :ok
  end

  defp partidas do
    asegurar_archivo()

    File.read!(@archivo)
    |> String.split("---", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parsear_bloque/1)
    |> Enum.filter(& &1)   # elimina nil
  end

  defp parsear_bloque(bloque) do
    lineas = String.split(bloque, "\n", trim: true)

    with true <- contiene_categoria?(lineas),
         categoria <- extraer_categoria(lineas),
         indice_puntajes <- indice_linea_puntajes(lineas),
         true <- indice_puntajes != nil do
      puntajes = extraer_puntajes(lineas, indice_puntajes)

      %{
        categoria: categoria,
        puntajes: puntajes
      }
    else
      _ -> nil
    end
  end

  defp contiene_categoria?(lineas) do
    Enum.any?(lineas, &String.starts_with?(&1, "Categoría:"))
  end

  defp extraer_categoria(lineas) do
    lineas
    |> Enum.find(&String.starts_with?(&1, "Categoría:"))
    |> String.replace("Categoría: ", "")
    |> String.trim()
  end

  defp indice_linea_puntajes(lineas) do
    Enum.find_index(lineas, &(&1 == "Puntajes:"))
  end

  defp extraer_puntajes(lineas, indice_puntajes) do
    lineas
    |> Enum.drop(indice_puntajes + 1)
    |> Enum.map(&parsear_linea_puntaje/1)
    |> Enum.filter(& &1)
  end

  defp parsear_linea_puntaje("- " <> contenido) do
    case String.split(contenido, ":") do
      [nombre_jugador, texto_puntaje] ->
        puntos = limpiar_y_convertir_puntaje(texto_puntaje)
        {String.trim(nombre_jugador), puntos}

      _ ->
        nil
    end
  end

  defp parsear_linea_puntaje(_otra_linea), do: nil

  defp limpiar_y_convertir_puntaje(texto) do
    texto
    |> String.trim()
    |> String.replace(~r/[^-0-9]/, "")   # deja solo números (y -)
    |> Integer.parse()
    |> case do
      {numero, _} -> numero
      :error -> 0
    end
  end

  def ranking_global do
    partidas()
    |> Enum.flat_map(& &1.puntajes)
    |> acumular_puntajes()
    |> ordenar_descendente()
  end

  def ranking_por_tema(categoria_buscada) do
    categoria_normalizada =
      categoria_buscada
      |> String.trim()
      |> String.downcase()

    partidas()
    |> Enum.filter(&(String.downcase(&1.categoria) == categoria_normalizada))
    |> Enum.flat_map(& &1.puntajes)
    |> acumular_puntajes()
    |> ordenar_descendente()
  end

  defp acumular_puntajes(pares_nombre_puntos) do
    pares_nombre_puntos
    |> Enum.reduce(%{}, fn {nombre, puntos}, acumulado ->
      Map.update(acumulado, nombre, puntos, &(&1 + puntos))
    end)
    |> Enum.map(fn {nombre, puntaje_total} ->
      %{nombre: nombre, puntaje_total: puntaje_total}
    end)
  end

  defp ordenar_descendente(lista) do
    Enum.sort_by(lista, & &1.puntaje_total, :desc)
  end
end
